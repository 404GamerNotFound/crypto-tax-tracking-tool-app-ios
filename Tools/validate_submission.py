#!/usr/bin/env python3
"""Validate the publisher-owned values required before an App Store archive."""
import argparse
import ipaddress
import plistlib
from pathlib import Path
import re
import sys
from urllib.parse import urlsplit
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / 'crypto-tax-tracking-tool-app-ios' / 'crypto-tax-tracking-tool-app-ios'


def public_https(value):
    try:
        url = urlsplit(value)
        host = url.hostname or ''
        if url.scheme != 'https' or not host or url.username or url.password or url.fragment:
            return False
        if url.port is not None and not 1 <= url.port <= 65535:
            return False
        if host == 'localhost' or host.endswith(('.local', '.invalid', '.test')):
            return False
        if any(host == x or host.endswith('.' + x) for x in ('example.com', 'example.net', 'example.org')):
            return False
        try:
            if not ipaddress.ip_address(host).is_global:
                return False
        except ValueError:
            if '.' not in host:
                return False
        return True
    except (ValueError, TypeError):
        return False


def validate(publication, manifest, info):
    errors = []
    if not str(publication.get('publisher', '')).strip():
        errors.append('Publication.plist: echter Herausgeber fehlt.')
    email = publication.get('contactEmail', '')
    if not re.fullmatch(r"[A-Za-z0-9.!#$%&'*+/=^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+", email) or not public_https('https://' + email.rsplit('@', 1)[-1]):
        errors.append('Publication.plist: gültige Support-/Datenschutz-Kontaktadresse fehlt.')
    for key in ('privacyURL', 'supportURL'):
        if not public_https(publication.get(key, '')):
            errors.append('Publication.plist: ' + key + ' muss eine echte öffentliche HTTPS-URL sein.')
    declarations = manifest.get('NSPrivacyAccessedAPITypes', [])
    if not any(item.get('NSPrivacyAccessedAPIType') == 'NSPrivacyAccessedAPICategoryUserDefaults'
               and 'CA92.1' in item.get('NSPrivacyAccessedAPITypeReasons', []) for item in declarations):
        errors.append('PrivacyInfo.xcprivacy: UserDefaults-Begründung CA92.1 fehlt.')
    if manifest.get('NSPrivacyTracking') is not False or manifest.get('NSPrivacyTrackingDomains'):
        errors.append('PrivacyInfo.xcprivacy: Tracking-Angaben passen nicht zur aktuellen App.')
    if manifest.get('NSPrivacyCollectedDataTypes') != []:
        errors.append('PrivacyInfo.xcprivacy: Datenerhebung prüfen; aktuelle App enthält keinen zentralen Erhebungsdienst.')
    if info.get('ITSAppUsesNonExemptEncryption') is not False:
        errors.append('Info.plist: Verschlüsselungsangabe für OS-eigenes HTTPS fehlt.')
    if not info.get('NSLocalNetworkUsageDescription', '').strip():
        errors.append('Info.plist: Zweck des lokalen Netzwerkzugriffs fehlt.')
    ats = info.get('NSAppTransportSecurity', {})
    if ats.get('NSAllowsArbitraryLoads') or ats.get('NSAllowsArbitraryLoadsInWebContent'):
        errors.append('Info.plist: globale HTTP-Freigabe ist nicht vorgesehen.')
    return errors


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--online', action='store_true', help='Datenschutz- und Supportseiten auf Erreichbarkeit prüfen')
    options = parser.parse_args()
    try:
        publication = plistlib.loads((APP / 'Publication.plist').read_bytes())
        manifest = plistlib.loads((APP / 'PrivacyInfo.xcprivacy').read_bytes())
        info = plistlib.loads((ROOT / 'Config' / 'Info.plist').read_bytes())
        errors = validate(publication, manifest, info)
        if options.online and not errors:
            for key in ('privacyURL', 'supportURL'):
                try:
                    request = Request(publication[key], headers={'User-Agent': 'CryptoBuch-Submission-Check/1.0'})
                    with urlopen(request, timeout=15) as response:
                        if not public_https(response.url) or response.status != 200:
                            raise ValueError('kein öffentliches HTTPS-Dokument')
                        if 'text/html' not in response.headers.get('Content-Type', ''):
                            raise ValueError('keine HTML-Seite')
                        if len(response.read(2048).strip()) < 100:
                            raise ValueError('Inhalt leer oder zu kurz')
                except Exception as error:
                    errors.append(key + ': Erreichbarkeitsprüfung fehlgeschlagen (' + type(error).__name__ + ').')
        for error in errors:
            print('error: ' + error, file=sys.stderr)
        if errors:
            print('Keine einreichungsfähige Konfiguration. Siehe Docs/APP_STORE_REVIEW.md.', file=sys.stderr)
            return 1
        print('Technische Veröffentlichungsangaben vollständig. Inhalte, Review-Zugang und App-Store-Metadaten weiterhin manuell prüfen.')
        return 0
    except (OSError, plistlib.InvalidFileException) as error:
        print('error: Veröffentlichungsdateien konnten nicht gelesen werden: ' + str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
