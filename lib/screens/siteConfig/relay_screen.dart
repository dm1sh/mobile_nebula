import 'package:flutter/material.dart';
import 'package:mobile_nebula/components/config/config_button_item.dart';
import 'package:mobile_nebula/components/config/config_checkbox_item.dart';
import 'package:mobile_nebula/components/config/config_item.dart';
import 'package:mobile_nebula/components/config/config_section.dart';
import 'package:mobile_nebula/components/form_page.dart';
import 'package:mobile_nebula/components/ip_form_field.dart';

class _RelayEntry {
  String address;

  _RelayEntry(this.address);
}

/// Nebula's relay.* settings edited by [RelayScreen]
class RelaySettings {
  bool useRelays;
  bool amRelay;
  List<String> relays;

  RelaySettings({required this.useRelays, required this.amRelay, required this.relays});
}

class RelayScreen extends StatefulWidget {
  const RelayScreen({super.key, required this.settings, required this.onSave});

  final RelaySettings settings;

  // Null renders the screen read-only for managed configurations
  final ValueChanged<RelaySettings>? onSave;

  @override
  RelayScreenState createState() => RelayScreenState();
}

class RelayScreenState extends State<RelayScreen> {
  late bool useRelays;
  late bool amRelay;
  final Map<Key, _RelayEntry> _relays = {};
  bool changed = false;

  @override
  void initState() {
    useRelays = widget.settings.useRelays;
    amRelay = widget.settings.amRelay;
    for (final address in widget.settings.relays) {
      _relays[UniqueKey()] = _RelayEntry(address);
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return FormPage(
      title: 'Relays',
      changed: changed,
      onSave: _onSave,
      child: Column(
        children: [
          ConfigSection(
            children: [
              ConfigCheckboxItem(
                label: Text('Use relays'),
                labelWidth: 150,
                content: Text('Connect through relays when a direct connection is unavailable'),
                checked: useRelays,
                onChanged: widget.onSave == null
                    ? null
                    : () {
                        setState(() {
                          changed = true;
                          useRelays = !useRelays;
                        });
                      },
              ),
              ConfigCheckboxItem(
                label: Text('Act as relay'),
                labelWidth: 150,
                content: Text('Forward traffic for other hosts'),
                checked: amRelay,
                onChanged: widget.onSave == null
                    ? null
                    : () {
                        setState(() {
                          changed = true;
                          amRelay = !amRelay;
                        });
                      },
              ),
            ],
          ),
          ConfigSection(label: 'Nebula IPs of relays peers can use to reach this host.', children: _buildRelays()),
        ],
      ),
    );
  }

  void _onSave() {
    Navigator.pop(context);
    if (widget.onSave != null) {
      List<String> addresses = [];
      _relays.forEach((_, entry) {
        final address = entry.address.trim();
        if (address.isNotEmpty) {
          addresses.add(address);
        }
      });

      widget.onSave!(RelaySettings(useRelays: useRelays, amRelay: amRelay, relays: amRelay ? [] : addresses));
    }
  }

  List<Widget> _buildRelays() {
    if (amRelay) {
      // A host configured to act as a relay may not specify relays of its own
      return [ConfigItem(labelWidth: 0, content: Text('Unavailable while acting as a relay'))];
    }

    List<Widget> items = [];

    _relays.forEach((key, entry) {
      items.add(
        ConfigItem(
          key: key,
          label: Align(
            alignment: Alignment.centerLeft,
            child: widget.onSave == null
                ? Container()
                : IconButton(
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.remove_circle, color: Theme.of(context).colorScheme.error),
                    onPressed: () => setState(() {
                      _removeRelay(key);
                      _dismissKeyboard();
                    }),
                  ),
          ),
          labelWidth: 70,
          content: Row(
            children: <Widget>[
              Expanded(
                child: widget.onSave == null
                    ? Text(entry.address, textAlign: TextAlign.end)
                    : IPFormField(
                        help: 'nebula ip',
                        textAlign: TextAlign.end,
                        ipOnly: true,
                        initialValue: entry.address,
                        autoSize: false,
                        onSaved: (v) {
                          if (v != null) {
                            entry.address = v;
                          }
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    });

    if (widget.onSave != null) {
      items.add(
        ConfigButtonItem(
          content: Text('Add another'),
          onPressed: () => setState(() {
            _addRelay();
            _dismissKeyboard();
          }),
        ),
      );
    }

    return items;
  }

  void _addRelay() {
    changed = true;
    _relays[UniqueKey()] = _RelayEntry('');
  }

  void _removeRelay(Key key) {
    changed = true;
    _relays.remove(key);
  }

  void _dismissKeyboard() {
    FocusScopeNode currentFocus = FocusScope.of(context);

    if (!currentFocus.hasPrimaryFocus) {
      currentFocus.unfocus();
    }
  }
}
