import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/history_controller.dart';
import '../../controllers/privacy_controller.dart';
import '../../controllers/zones_controller.dart';
import '../../widgets/companion_ui.dart';
import 'history_view.dart';
import 'privacy_view.dart';
import 'settings_view.dart';
import 'zones_view.dart';

/// Inicio del acompañante con sus cuatro pestañas (HU10 a HU14): Mapa,
/// Historial, Ajustes y Privacidad.
class CompanionShellView extends StatefulWidget {
  const CompanionShellView({
    super.key,
    required this.onChangeProfile,
    this.baseMap = true,
  });

  final VoidCallback onChangeProfile;

  /// `false` en las pruebas: el mapa no descarga teselas.
  final bool baseMap;

  @override
  State<CompanionShellView> createState() => _CompanionShellViewState();
}

class _CompanionShellViewState extends State<CompanionShellView> {
  CompanionTab _tab = CompanionTab.map;

  /// Al volver a una pestaña se recargan sus datos, por si cambiaron.
  void _select(CompanionTab tab) {
    setState(() => _tab = tab);
    switch (tab) {
      case CompanionTab.map:
        Get.find<ZonesController>().load();
      case CompanionTab.history:
        Get.find<HistoryController>().load();
      case CompanionTab.privacy:
        Get.find<PrivacyController>().load();
      case CompanionTab.settings:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: [
          ZonesView(baseMap: widget.baseMap),
          const HistoryView(),
          SettingsView(onChangeProfile: widget.onChangeProfile),
          const PrivacyView(),
        ],
      ),
      bottomNavigationBar: PillNav(current: _tab, onSelect: _select),
    );
  }
}
