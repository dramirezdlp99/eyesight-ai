import 'package:eyesight_ai/core/config/app_constants.dart';
import 'package:eyesight_ai/domain/entities/app_settings.dart';
import 'package:eyesight_ai/domain/entities/detection_record.dart';
import 'package:eyesight_ai/domain/entities/proximity.dart';
import 'package:eyesight_ai/domain/entities/risk_zone.dart';
import 'package:eyesight_ai/domain/entities/user_profile.dart';
import 'package:eyesight_ai/domain/entities/video_source_kind.dart';
import 'package:eyesight_ai/domain/entities/zone_audit_entry.dart';
import 'package:eyesight_ai/domain/entities/zone_origin.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/builders.dart';

void main() {
  group('UserProfile', () {
    test('solo acompañante no es usuario final', () {
      expect(UserProfile.totalBlindness.isEndUser, isTrue);
      expect(UserProfile.lowVision.isEndUser, isTrue);
      expect(UserProfile.companion.isEndUser, isFalse);
    });

    test('fromName reconoce los nombres guardados y rechaza otros', () {
      expect(UserProfile.fromName('lowVision'), UserProfile.lowVision);
      expect(UserProfile.fromName('admin'), isNull);
      expect(UserProfile.fromName(null), isNull);
    });
  });

  group('Proximity', () {
    test('cerca es más urgente que media distancia y lejos', () {
      expect(Proximity.near.isCloserThan(Proximity.medium), isTrue);
      expect(Proximity.medium.isCloserThan(Proximity.far), isTrue);
      expect(Proximity.far.isCloserThan(Proximity.near), isFalse);
      expect(Proximity.near.spoken, 'cerca');
      expect(Proximity.medium.spoken, 'a media distancia');
    });
  });

  group('RiskZone', () {
    test('ida y vuelta por mapa conserva todos los campos', () {
      final z = zone(origin: ZoneOrigin.manual, count: 3)
          .copyWith(note: 'Frente a la tienda');
      expect(RiskZone.fromMap(z.toMap()), z);
    });

    test('rechaza registros incompletos o fuera de rango', () {
      final base = zone().toMap();
      expect(
        () => RiskZone.fromMap({...base, 'lat': 120.0}),
        throwsFormatException,
      );
      expect(
        () => RiskZone.fromMap({...base, 'origin': 'remoto'}),
        throwsFormatException,
      );
      expect(
        () => RiskZone.fromMap({...base, 'origin': 7}),
        throwsFormatException,
      );
      expect(
        () => RiskZone.fromMap({...base}..remove('id')),
        throwsFormatException,
      );
      expect(
        () => RiskZone.fromMap({...base, 'count': 0}),
        throwsFormatException,
      );
    });

    test('registros antiguos sin lastSeenAt usan createdAt', () {
      final map = zone().toMap()..remove('lastSeenAt');
      expect(RiskZone.fromMap(map).lastSeenAt, t0);
    });
  });

  group('DetectionRecord', () {
    test('admite registros sin posición GPS (HU06, CA4)', () {
      final r = DetectionRecord(
        label: 'person',
        confidence: 0.77,
        proximity: Proximity.medium,
        timestamp: t0,
      );
      final back = DetectionRecord.fromMap(r.toMap());
      expect(back, r);
      expect(back.hasPosition, isFalse);
    });

    test('rechaza registros dañados', () {
      expect(
        () => DetectionRecord.fromMap({'label': 'person'}),
        throwsFormatException,
      );
      expect(
        () => DetectionRecord.fromMap({
          'label': 'person',
          'confidence': 0.5,
          'proximity': 'near',
          'timestamp': 1,
          'lat': 'uno',
        }),
        throwsFormatException,
      );
    });
  });

  group('AppSettings', () {
    test('valores por defecto coinciden con el informe', () {
      const s = AppSettings();
      expect(s.profile, isNull);
      expect(s.alertRadiusM, 20);
      expect(s.confidenceThreshold, 0.5);
      expect(s.videoSource, VideoSourceKind.phone);
      expect(s.vibration, isTrue);
      expect(s.autoZones, isTrue);
    });

    test('ida y vuelta por mapa', () {
      const s = AppSettings(
        profile: UserProfile.lowVision,
        speechRate: 1.5,
        volume: 0.7,
        alertRadiusM: 35,
        confidenceThreshold: 0.6,
        videoSource: VideoSourceKind.usb,
        vibration: false,
        autoZones: false,
      );
      expect(AppSettings.fromMap(s.toMap()), s);
    });

    test('valores dañados o fuera de rango vuelven al valor por defecto', () {
      final s = AppSettings.fromMap({
        'profile': 'root',
        'alertRadiusM': 500,
        'confidenceThreshold': 0.1,
        'speechRate': double.nan,
        'videoSource': 'satelite',
        'vibration': 'si',
      });
      expect(s, const AppSettings());
    });

    test('copyWith puede borrar el perfil y restablecer conserva el perfil',
        () {
      const s = AppSettings(profile: UserProfile.companion, alertRadiusM: 50);
      expect(s.copyWith(clearProfile: true).profile, isNull);
      final reset = s.resetKeepingProfile();
      expect(reset.profile, UserProfile.companion);
      expect(reset.alertRadiusM, AppConstants.defaultAlertRadiusM);
    });
  });

  group('ZoneAuditEntry', () {
    test('ida y vuelta por mapa', () {
      final e = ZoneAuditEntry(
        action: AuditAction.deleted,
        zoneId: 'z1',
        zoneType: 'step',
        timestamp: t0,
      );
      expect(ZoneAuditEntry.fromMap(e.toMap()), e);
      expect(
        () => ZoneAuditEntry.fromMap({'action': 'hacked'}),
        throwsFormatException,
      );
    });
  });
}
