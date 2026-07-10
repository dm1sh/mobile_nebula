import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:mobile_nebula/components/app_text_form_field.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_page_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/models/ip_and_port.dart';
import 'package:mobile_nebula/models/site.dart';
import 'package:mobile_nebula/models/unsafe_route.dart';
import 'package:mobile_nebula/screens/siteConfig/cipher_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/dns_lookup_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/dns_resolvers_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/excluded_apps_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/log_verbosity_screen.dart';
import 'package:mobile_nebula/screens/siteConfig/rendered_config_screen.dart';
import 'package:mobile_nebula/services/utils.dart';
import 'package:mobile_nebula/validators/ip_validator.dart';

import 'unsafe_routes_screen.dart';

//TODO: form validation (seconds and port)
//TODO: wire up the focus nodes, add a done/next/prev to the keyboard
//TODO: fingerprint blacklist
//TODO: show site id here

class Advanced {
  int lhDuration;
  int port;
  String cipher;
  String verbosity;
  List<UnsafeRoute> unsafeRoutes;
  int mtu;
  List<String> dnsResolvers;
  List<String> matchDomains;
  List<String> excludedApps;
  IPAndPort? socks5Proxy;
  String staticMapNetwork;

  Advanced({
    required this.lhDuration,
    required this.port,
    required this.cipher,
    required this.verbosity,
    required this.unsafeRoutes,
    required this.mtu,
    required this.dnsResolvers,
    required this.matchDomains,
    required this.excludedApps,
    required this.socks5Proxy,
    required this.staticMapNetwork,
  });
}

class AdvancedScreen extends StatefulWidget {
  const AdvancedScreen({super.key, required this.site, required this.onSave});

  final Site site;
  final ValueChanged<Advanced> onSave;

  @override
  AdvancedScreenState createState() => AdvancedScreenState();
}

class AdvancedScreenState extends State<AdvancedScreen> {
  late Advanced settings;
  late TextEditingController proxyHostController;
  late TextEditingController proxyPortController;
  var changed = false;

  @override
  void initState() {
    settings = Advanced(
      lhDuration: widget.site.lhDuration,
      port: widget.site.port,
      cipher: widget.site.cipher,
      verbosity: widget.site.logVerbosity,
      unsafeRoutes: widget.site.unsafeRoutes,
      mtu: widget.site.mtu,
      dnsResolvers: widget.site.dnsResolvers,
      matchDomains: widget.site.matchDomains,
      excludedApps: widget.site.excludedApps,
      socks5Proxy: widget.site.socks5Proxy,
      staticMapNetwork: widget.site.staticMapNetwork,
    );
    proxyHostController = TextEditingController(text: settings.socks5Proxy?.ip ?? '');
    proxyPortController = TextEditingController(text: settings.socks5Proxy?.port?.toString() ?? '');
    super.initState();
  }

  @override
  void dispose() {
    proxyHostController.dispose();
    proxyPortController.dispose();
    super.dispose();
  }

  String? _validateProxyHost(String? value) {
    final host = (value ?? '').trim();
    final port = proxyPortController.text.trim();
    if (host.isEmpty && port.isEmpty) {
      return null;
    }
    if (host.isEmpty) {
      return 'Required when a proxy port is set';
    }

    final (valid, _) = ipValidator(host);
    if (!valid) {
      return 'Please enter a valid proxy IP address';
    }

    return null;
  }

  String? _validateProxyPort(String? value) {
    final host = proxyHostController.text.trim();
    final port = (value ?? '').trim();
    if (host.isEmpty && port.isEmpty) {
      return null;
    }
    if (port.isEmpty) {
      return 'Required when a proxy IP is set';
    }

    final parsed = int.tryParse(port);
    if (parsed == null || parsed < 1 || parsed > 65535) {
      return 'Please enter a valid port';
    }

    return null;
  }

  void _saveProxySettings() {
    final host = proxyHostController.text.trim();
    final port = int.tryParse(proxyPortController.text.trim());
    if (host.isEmpty && port == null) {
      settings.socks5Proxy = null;
      return;
    }

    settings.socks5Proxy = IPAndPort(host, port);
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Advanced Settings',
      changed: changed,
      onSave: () {
        _saveProxySettings();
        Navigator.pop(context);
        widget.onSave(settings);
      },
      child: Column(
        children: [
          ConfigSection(
            children: [
              ConfigItem(
                label: Text("Lighthouse interval"),
                labelWidth: 200,
                //TODO: Auto select on focus?
                content: widget.site.managed
                    ? Text("${settings.lhDuration} seconds", textAlign: TextAlign.right)
                    : AppTextFormField(
                        initialValue: settings.lhDuration.toString(),
                        keyboardType: TextInputType.number,
                        suffix: Text("seconds"),
                        textAlign: TextAlign.right,
                        maxLength: 5,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onSaved: (val) {
                          setState(() {
                            if (val != null) {
                              settings.lhDuration = int.parse(val);
                            }
                          });
                        },
                      ),
              ),
              ConfigItem(
                label: Text("Listen port"),
                labelWidth: 150,
                //TODO: Auto select on focus?
                content: widget.site.managed
                    ? Text(settings.port.toString(), textAlign: TextAlign.right)
                    : AppTextFormField(
                        initialValue: settings.port.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        maxLength: 5,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onSaved: (val) {
                          setState(() {
                            if (val != null) {
                              settings.port = int.parse(val);
                            }
                          });
                        },
                      ),
              ),
              ConfigItem(
                label: Text("MTU"),
                labelWidth: 150,
                content: widget.site.managed
                    ? Text(settings.mtu.toString(), textAlign: TextAlign.right)
                    : AppTextFormField(
                        initialValue: settings.mtu.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        maxLength: 5,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onSaved: (val) {
                          setState(() {
                            if (val != null) {
                              settings.mtu = int.parse(val);
                            }
                          });
                        },
                      ),
              ),
              ConfigPageItem(
                disabled: widget.site.managed,
                label: Text('Cipher'),
                labelWidth: 150,
                content: Text(settings.cipher, textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return CipherScreen(
                      cipher: settings.cipher,
                      onSave: (cipher) {
                        setState(() {
                          settings.cipher = cipher;
                          changed = true;
                        });
                      },
                    );
                  });
                },
              ),
              ConfigPageItem(
                disabled: widget.site.managed,
                label: Text('Log verbosity'),
                labelWidth: 150,
                content: Text(settings.verbosity, textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return LogVerbosityScreen(
                      verbosity: settings.verbosity,
                      onSave: (verbosity) {
                        setState(() {
                          settings.verbosity = verbosity;
                          changed = true;
                        });
                      },
                    );
                  });
                },
              ),
              ConfigPageItem(
                label: Text('Unsafe routes'),
                labelWidth: 150,
                content: Text(Utils.itemCountFormat(settings.unsafeRoutes.length), textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return UnsafeRoutesScreen(
                      unsafeRoutes: settings.unsafeRoutes,
                      onSave: widget.site.managed
                          ? null
                          : (routes) {
                              setState(() {
                                settings.unsafeRoutes = routes;
                                changed = true;
                              });
                            },
                    );
                  });
                },
              ),
              ConfigPageItem(
                label: Text('DNS resolvers'),
                labelWidth: 150,
                content: Text(Utils.itemCountFormat(settings.dnsResolvers.length), textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return DnsResolversScreen(
                      dnsResolvers: settings.dnsResolvers,
                      matchDomains: settings.matchDomains,
                      onSave: widget.site.managed
                          ? null
                          : (resolvers) {
                              setState(() {
                                settings.dnsResolvers = resolvers;
                                changed = true;
                              });
                            },
                      onSaveMatchDomains: widget.site.managed
                          ? null
                          : (domains) {
                              setState(() {
                                settings.matchDomains = domains;
                                changed = true;
                              });
                            },
                    );
                  });
                },
              ),
              ConfigItem(
                label: Text('SOCKS5 proxy'),
                labelWidth: 150,
                content: Row(
                  children: [
                    Expanded(
                      child: AppTextFormField(
                        controller: proxyHostController,
                        placeholder: 'Optional IP',
                        textAlign: TextAlign.right,
                        maxLength: 45,
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\.:a-fA-F]+'))],
                        validator: _validateProxyHost,
                      ),
                    ),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text(':')),
                    SizedBox(
                      width: 70,
                      child: AppTextFormField(
                        controller: proxyPortController,
                        placeholder: 'port',
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        maxLength: 5,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: _validateProxyPort,
                      ),
                    ),
                  ],
                ),
              ),
              ConfigPageItem(
                disabled: widget.site.managed,
                label: Text('DNS lookup mode'),
                labelWidth: 150,
                content: Text(settings.staticMapNetwork, textAlign: TextAlign.end),
                onPressed: () {
                  Utils.openPage(context, (context) {
                    return DnsLookupScreen(
                      staticMapNetwork: settings.staticMapNetwork,
                      onSave: (staticMapNetwork) {
                        setState(() {
                          settings.staticMapNetwork = staticMapNetwork;
                          changed = true;
                        });
                      },
                    );
                  });
                },
              ),
              if (Platform.isAndroid)
                ConfigPageItem(
                  label: Text('Excluded apps'),
                  labelWidth: 150,
                  content: Text(
                    settings.excludedApps.isEmpty ? 'None' : Utils.itemCountFormat(settings.excludedApps.length),
                    textAlign: TextAlign.end,
                  ),
                  onPressed: () {
                    Utils.openPage(context, (context) {
                      return ExcludedAppsScreen(
                        excludedApps: settings.excludedApps,
                        onSave: (apps) {
                          setState(() {
                            settings.excludedApps = apps;
                            changed = true;
                          });
                        },
                      );
                    });
                  },
                ),
            ],
          ),
          ConfigSection(
            children: <Widget>[
              ConfigPageItem(
                label: Text('View rendered config'),
                onPressed: () async {
                  try {
                    var config = await widget.site.renderConfig();
                    if (!context.mounted) {
                      return;
                    }
                    Utils.openPage(context, (context) {
                      return RenderedConfigScreen(config: config, name: widget.site.name);
                    });
                  } catch (err) {
                    Utils.popError('Failed to render the site config', err.toString());
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
