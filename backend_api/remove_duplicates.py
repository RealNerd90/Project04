import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'backend.settings')
django.setup()

from attendance.models import AttendanceRecord
from django.db.models import Count

def remove_duplicates():
    # Find combinations of name and date that have more than 1 record
    duplicates = AttendanceRecord.objects.values('name', 'date').annotate(count=Count('id')).filter(count__gt=1)
    
    total_deleted = 0
    
    for duplicate in duplicates:
        # Get all records for this name and date, order by ID (earliest first)
        records = AttendanceRecord.objects.filter(
            name=duplicate['name'],
            date=duplicate['date']
        ).order_by('id')
        
        # Keep the first one, delete the rest
        if records.count() > 1:
            records_to_delete = records[1:]
            for record in records_to_delete:
                print(f"Deleting duplicate for {record.name} on {record.date} (ID: {record.id})")
                record.delete()
                total_deleted += 1
                
    print(f"Successfully deleted {total_deleted} duplicate records.")

if __name__ == '__main__':
    remove_duplicates()
