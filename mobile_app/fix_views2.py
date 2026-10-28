import os

file_path = r'c:\Users\Hp\Documents\Project03\attendance\views.py'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('@csrf_exempt\n@csrf_exempt\ndef manual_login', '@csrf_exempt\ndef manual_login')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Cleaned views.py")
