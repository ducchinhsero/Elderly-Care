import 'package:elder_health_monitor/core/services/lan_setup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LanSetupService', () {
    test('normalizes IP, hostname and URL input', () {
      expect(
          LanSetupService.normalizeGatewayHost('10.10.56.149'), '10.10.56.149');
      expect(
          LanSetupService.normalizeGatewayHost(
              'http://10.10.56.149:8000/health'),
          '10.10.56.149');
      expect(LanSetupService.normalizeGatewayHost('elderlycare.local:8000'),
          'elderlycare.local');
      expect(LanSetupService.baseUrlForHost('10.10.56.149'),
          'http://10.10.56.149:8000');
    });

    test('detects private IPv4 LAN addresses', () {
      expect(LanSetupService.isPrivateIpv4('10.10.56.149'), isTrue);
      expect(LanSetupService.isPrivateIpv4('172.16.1.10'), isTrue);
      expect(LanSetupService.isPrivateIpv4('192.168.1.5'), isTrue);
      expect(LanSetupService.isPrivateIpv4('8.8.8.8'), isFalse);
      expect(LanSetupService.isPrivateIpv4('127.0.0.1'), isFalse);
    });

    test('builds same and adjacent /24 scan candidates', () {
      final hosts = LanSetupService.candidateHostsForAddress('10.10.56.149');

      expect(hosts, contains('10.10.55.1'));
      expect(hosts, contains('10.10.56.1'));
      expect(hosts, contains('10.10.57.254'));
      expect(hosts, isNot(contains('10.10.56.149')));
    });

    test('scan accepts only valid health responders', () async {
      final service = LanSetupService(
        healthChecker: (host) async {
          if (host == '10.10.56.3') {
            return LanDevice(
              host: host,
              baseUrl: 'http://$host:8000',
              health: const {'status': 'ok'},
            );
          }
          return null;
        },
      );

      final devices = await service.scanLan(
        candidateHosts: const ['10.10.56.2', '10.10.56.3'],
        concurrency: 2,
      );

      expect(devices, hasLength(1));
      expect(devices.single.host, '10.10.56.3');
    });
  });
}
