package mobileNebula

import (
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/netip"
	"os"
	"runtime"
	"runtime/debug"
	"sync"

	"github.com/google/gopacket"
	"github.com/google/gopacket/layers"
	"github.com/sirupsen/logrus"
	"github.com/slackhq/nebula"
	nc "github.com/slackhq/nebula/config"
	"github.com/slackhq/nebula/overlay"
	"github.com/slackhq/nebula/util"
	"golang.org/x/net/proxy"
)

// ProxyDevice wraps a nebula.Device and routes non-nebula traffic to a SOCKS5 proxy.
type ProxyDevice struct {
	device    nebula.Device
	config    *nc.C
	proxyIP   string
	proxyPort int
	logger    *logrus.Logger
	handler   *socks5Handler
	mu        sync.Mutex
}

func (p *ProxyDevice) Read(b []byte) (int, error) {
	for {
		// Read a packet from the underlying TUN device
		tempBuf := make([]byte, 65535)
		n, err := p.device.Read(tempBuf)
		if err != nil {
			return n, err
		}

		packetData := tempBuf[:n]
		
		// Parse the IP packet
		packet := gopacket.NewPacket(packetData, layers.LayerTypeIPv4, gopacket.Default)
		if packet.Layer(layers.LayerTypeIPv4) == nil {
			// Not IPv4, pass to Nebula
			copy(b, packetData)
			return n, nil
		}

		ipLayer := packet.Layer(layers.LayerTypeIPv4).(*layers.IPv4)
		dstIP := net.IP(ipLayer.DstIP)

		// Route to Nebula if the destination is a Nebula IP or an Unsafe route
		if p.isNebulaOrUnsafe(dstIP) {
			copy(b, packetData)
			return n, nil
		}

		// Otherwise, route to SOCKS5 proxy
		p.handler.handlePacket(packetData)
		
		// Packet consumed by proxy, loop to find a packet Nebula wants
	}
}

func (p *ProxyDevice) isNebulaOrUnsafe(ip net.IP) bool {
	// Check Unsafe Routes
	for _, route := range p.config.Tun.UnsafeRoutes {
		_, cidr, err := net.ParseCIDR(route.Route)
		if err == nil && cidr.Contains(ip) {
			return true
		}
	}

	// Check Nebula Routes
	for _, route := range p.config.Tun.Routes {
		_, cidr, err := net.ParseCIDR(route.Route)
		if err == nil && cidr.Contains(ip) {
			return true
		}
	}

	return false
}

func (p *ProxyDevice) Write(b []byte) (int, error) {
	return p.device.Write(b)
}

func (p *ProxyDevice) Close() error {
	if p.handler != nil {
		p.handler.Close()
	}
	return p.device.Close()
}

type socks5Handler struct {
	proxyAddr string
	logger    *logrus.Logger
	dialer    proxy.Dialer
	conns     map[string]net.Conn
	mu        sync.Mutex
}

func newSocks5Handler(ip string, port int, logger *logrus.Logger) *socks5Handler {
	addr := fmt.Sprintf("%s:%d", ip, port)
	return &socks5Handler{
		proxyAddr: addr,
		logger:    logger,
		dialer:    proxy.SOCKS5(addr, nil, nil),
		conns:     make(map[string]net.Conn),
	}
}

func (h *socks5Handler) handlePacket(data []byte) {
	packet := gopacket.NewPacket(data, layers.LayerTypeIPv4, gopacket.Default)
	
	if tcpLayer := packet.Layer(layers.LayerTypeTCP); tcpLayer != nil {
		tcp := tcpLayer.(*layers.TCP)
		h.handleTCP(packet, tcp)
	} else if udpLayer := packet.Layer(layers.LayerTypeUDP); udpLayer != nil {
		udp := udpLayer.(*layers.UDP)
		h.handleUDP(packet, udp)
	}
}

func (h *socks5Handler) handleTCP(packet gopacket.Packet, tcp *layers.TCP) {
	ipLayer := packet.Layer(layers.LayerTypeIPv4).(*layers.IPv4)
	src := fmt.Sprintf("%s:%d", ipLayer.SrcIP, tcp.SrcPort)
	dst := fmt.Sprintf("%s:%d", ipLayer.DstIP, tcp.DstPort)
	connKey := src + "->" + dst

	h.mu.Lock()
	conn, ok := h.conns[connKey]
	h.mu.Unlock()

	if !ok {
		var err error
		conn, err = h.dialer.Dial("tcp", dst)
		if err != nil {
			h.logger.Errorf("SOCKS5 dial error: %v", err)
			return
		}
		h.mu.Lock()
		h.conns[connKey] = conn
		h.mu.Unlock()
	}

	payload := tcp.Payload
	if len(payload) > 0 {
		conn.Write(payload)
	}
}

func (h *socks5Handler) handleUDP(packet gopacket.Packet, udp *layers.UDP) {
	ipLayer := packet.Layer(layers.LayerTypeIPv4).(*layers.IPv4)
	dst := fmt.Sprintf("%s:%d", ipLayer.DstIP, udp.DstPort)
	
	conn, err := h.dialer.Dial("udp", dst)
	if err != nil {
		h.logger.Errorf("SOCKS5 UDP dial error: %v", err)
		return
	}
	defer conn.Close()
	conn.Write(udp.Payload)
}

func (h *socks5Handler) Close() {
	h.mu.Lock()
	defer h.mu.Unlock()
	for _, conn := range h.conns {
		conn.Close()
	}
}

type Nebula struct {
	c      *nebula.Control
	l      *logrus.Logger
	config *nc.C
}

func init() {
	// Reduces memory utilization according to https://twitter.com/felixge/status/1355846360562589696?s=20
	runtime.MemProfileRate = 0
}

func NewNebula(configData string, key string, logFile string, tunFd int) (*Nebula, error) {
	// GC more often, largely for iOS due to extension 15mb limit
	debug.SetGCPercent(20)

	yamlConfig, err := RenderConfig(configData, key)
	if err != nil {
		return nil, err
	}

	l := logrus.New()
	f, err := os.OpenFile(logFile, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0644)
	if err != nil {
		return nil, err
	}
	l.SetOutput(f)

	c := nc.NewC(l)
	err = c.LoadString(yamlConfig)
	if err != nil {
		return nil, fmt.Errorf("failed to load config: %s", err)
	}

	//TODO: inject our version
	device := overlay.NewFdDeviceFromConfig(&tunFd)
	
	// Wrap device with ProxyDevice if proxy is configured
	// We need to extract proxy settings from the parsed config
	var proxyIP string
	var proxyPort int
	if c.GetString("proxy_ip", "") != "" {
		proxyIP = c.GetString("proxy_ip", "")
		proxyPort = c.GetInt("proxy_port", 0)
		device = &ProxyDevice{
			device:    device,
			config:    c,
			proxyIP:   proxyIP,
			proxyPort: proxyPort,
			logger:    l,
			handler:   newSocks5Handler(proxyIP, proxyPort, l),
		}
	}

	ctrl, err := nebula.Main(c, false, "", l, device)
	if err != nil {
		switch v := err.(type) {
		case *util.ContextualError:
			v.Log(l)
			return nil, v.Unwrap()
		default:
			l.WithError(err).Error("Failed to start")
			return nil, err
		}
	}

	return &Nebula{ctrl, l, c}, nil
}

func (n *Nebula) Log(v string) {
	n.l.Println(v)
}

func (n *Nebula) Start() {
	n.c.Start()
}

func (n *Nebula) ShutdownBlock() {
	n.c.ShutdownBlock()
}

func (n *Nebula) Stop() {
	n.c.Stop()
}

func (n *Nebula) Rebind(reason string) {
	n.l.Debugf("Rebinding UDP listener and updating lighthouses due to %s", reason)
	n.c.RebindUDPServer()
}

func (n *Nebula) Reload(configData string, key string) error {
	n.l.Info("Reloading Nebula")
	yamlConfig, err := RenderConfig(configData, key)
	if err != nil {
		return err
	}

	return n.config.ReloadConfigString(yamlConfig)
}

func (n *Nebula) ListHostmap(pending bool) (string, error) {
	hosts := n.c.ListHostmapHosts(pending)
	b, err := json.Marshal(hosts)
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func (n *Nebula) ListIndexes(pending bool) (string, error) {
	indexes := n.c.ListHostmapIndexes(pending)
	b, err := json.Marshal(indexes)
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func (n *Nebula) GetHostInfoByVpnIp(vpnIp string, pending bool) (string, error) {
	netVpnIp, err := netip.ParseAddr(vpnIp)
	if err != nil {
		return "", err
	}

	b, err := json.Marshal(n.c.GetHostInfoByVpnAddr(netVpnIp, pending))
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func (n *Nebula) CloseTunnel(vpnIp string) bool {
	netVpnIp, err := netip.ParseAddr(vpnIp)
	if err != nil {
		return false
	}

	return n.c.CloseTunnel(netVpnIp, false)
}

func (n *Nebula) SetRemoteForTunnel(vpnIp string, addr string) (string, error) {
	udpAddr, err := netip.ParseAddrPort(addr)
	if err != nil {
		return "", errors.New("could not parse udp address")
	}

	netVpnIp, err := netip.ParseAddr(vpnIp)
	if err != nil {
		return "", errors.New("could not parse vpnIp")
	}

	b, err := json.Marshal(n.c.SetRemoteForTunnel(netVpnIp, udpAddr))
	if err != nil {
		return "", err
	}

	return string(b), nil
}

func (n *Nebula) Sleep() {
	if closed := n.c.CloseAllTunnels(true); closed > 0 {
		n.l.WithField("tunnels", closed).Info("Sleep called, closed non lighthouse tunnels")
	}
}
