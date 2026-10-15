"""Validate secret presence/shape without printing credential values."""
import base64
import binascii
import os
import re
import sys

REQUIRED = (
    'APPLE_TEAM_ID', 'APP_STORE_CONNECT_KEY_ID',
    'APP_STORE_CONNECT_ISSUER_ID', 'APP_STORE_CONNECT_API_KEY_P8_BASE64',
    'APPLE_DISTRIBUTION_CERT_P12_BASE64', 'APPLE_DISTRIBUTION_CERT_PASSWORD',
)

def validate(env):
    errors = [f'Missing required GitHub Actions secret: {name}'
              for name in REQUIRED if not env.get(name)]
    for name, pattern in (
        ('APPLE_TEAM_ID', r'[A-Z0-9]{10}'),
        ('APP_STORE_CONNECT_KEY_ID', r'[A-Z0-9]{10}'),
        ('APP_STORE_CONNECT_ISSUER_ID', r'[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}'),
    ):
        if env.get(name) and not re.fullmatch(pattern, env[name]):
            errors.append(f'Invalid format for secret: {name}')
    for name in ('APP_STORE_CONNECT_API_KEY_P8_BASE64', 'APPLE_DISTRIBUTION_CERT_P12_BASE64'):
        if not env.get(name):
            continue
        try:
            decoded = base64.b64decode(''.join(env[name].split()), validate=True)
            if not decoded:
                raise ValueError()
            if name.endswith('P8_BASE64') and b'-----BEGIN PRIVATE KEY-----' not in decoded:
                raise ValueError()
        except (ValueError, binascii.Error):
            errors.append(f'Invalid encoded signing material: {name}')
    return errors

if __name__ == '__main__':
    failures = validate(os.environ)
    for failure in failures:
        print('::error::' + failure)
    if failures:
        sys.exit(1)
    print('Signing inputs present and structurally valid; Apple authorization remains unverified.')
