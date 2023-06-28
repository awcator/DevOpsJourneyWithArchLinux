from cryptography.fernet import Fernet

key = 'QkhVSFdPUUlVR0tIUlhQCg=='

f = Fernet(key)

token = 'AAAAAAAA'

print(f.decrypt(token))
