import os

file_path = r'c:\Users\Hp\Documents\Project03\attendance\views.py'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Fix the broken line
content = content.replace('@csrf_exempt`ndef manual_login(request: HttpRequest) -> HttpResponse:', '@csrf_exempt\ndef manual_login(request: HttpRequest) -> HttpResponse:')

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed views.py")
