#!/usr/bin/env python3

import binascii
import struct
import os
from collections import Counter
import re
from datetime import datetime

def find_date_patterns(data, offset):
    """Look for common date storage patterns in binary data"""
    potential_dates = []
    
    if len(data) >= offset + 4:
        unix_timestamp = struct.unpack('<I', data[offset:offset+4])[0]
        if 0 < unix_timestamp < 0xFFFFFFFF:
            try:
                date = datetime.fromtimestamp(unix_timestamp)
                if 1900 < date.year < 2100:
                    potential_dates.append((offset, f"Possible Unix timestamp: {date}"))
            except:
                pass
    
    if len(data) >= offset + 2:
        year = struct.unpack('<H', data[offset:offset+2])[0]
        if 1800 < year < 2100:
            potential_dates.append((offset, f"Possible year: {year}"))
    
    return potential_dates

def analyze_chunk(data, base_offset=0):
    """Analyze a chunk of binary data"""
    chunk_stats = {
        'date_patterns': [],
        'record_starts': [],
        'text_regions': []
    }
    
    # Look for date patterns every 4 bytes
    for i in range(0, len(data)-8, 4):
        dates = find_date_patterns(data, i)
        if dates:
            # Adjust offsets to account for chunk position
            chunk_stats['date_patterns'].extend(
                (base_offset + offset, desc) for offset, desc in dates
            )
    
    # Look for potential record starts
    for i in range(len(data) - 8):
        # Pattern: null bytes followed by consistent data
        if (data[i:i+4] == b'\x00\x00\x00\x00' and 
            data[i+4:i+8].isalnum()):
            chunk_stats['record_starts'].append(base_offset + i)
    
    # Find text regions
    text_region = []
    current_pos = 0
    
    for byte in data:
        if 32 <= byte <= 126 or byte in (9, 10, 13):
            text_region.append((current_pos, chr(byte)))
        elif text_region:
            if len(text_region) > 4:
                text = ''.join(char for _, char in text_region)
                chunk_stats['text_regions'].append({
                    'offset': base_offset + text_region[0][0],
                    'length': len(text_region),
                    'text': text
                })
            text_region = []
        current_pos += 1
    
    return chunk_stats

def analyze_binary_file(filepath, chunk_size=1024*1024):  # 1MB chunks
    """
    Analyze entire binary file in chunks
    """
    stats = {
        'file_size': 0,
        'date_patterns': [],
        'record_starts': [],
        'text_regions': [],
        'record_sizes': Counter()
    }
    
    file_size = os.path.getsize(filepath)
    stats['file_size'] = file_size
    
    print(f"Analyzing file of size {file_size:,} bytes...")
    
    with open(filepath, 'rb') as f:
        # Analyze first chunk in detail (for header information)
        first_chunk = f.read(min(chunk_size, file_size))
        print("\nFirst 64 bytes:")
        for i in range(0, min(64, len(first_chunk)), 16):
            chunk = first_chunk[i:i + 16]
            hex_values = ' '.join(f'{b:02x}' for b in chunk)
            ascii_values = ''.join(chr(b) if 32 <= b <= 126 else '.' for b in chunk)
            print(f'{i:04x}: {hex_values:<48} | {ascii_values}')
        
        # Reset file pointer
        f.seek(0)
        
        # Process file in chunks
        current_offset = 0
        chunks_processed = 0
        
        while current_offset < file_size:
            chunk = f.read(chunk_size)
            if not chunk:
                break
                
            chunk_stats = analyze_chunk(chunk, current_offset)
            
            # Merge chunk statistics into overall statistics
            stats['date_patterns'].extend(chunk_stats['date_patterns'])
            stats['record_starts'].extend(chunk_stats['record_starts'])
            stats['text_regions'].extend(chunk_stats['text_regions'])
            
            # Calculate distances between record starts
            if len(chunk_stats['record_starts']) > 1:
                distances = [chunk_stats['record_starts'][i+1] - chunk_stats['record_starts'][i] 
                           for i in range(len(chunk_stats['record_starts'])-1)]
                stats['record_sizes'].update(distances)
            
            current_offset += len(chunk)
            chunks_processed += 1
            if chunks_processed % 10 == 0:
                print(f"Processed {current_offset:,} of {file_size:,} bytes...")

    # Analyze record sizes
    common_sizes = stats['record_sizes'].most_common(5)
    if common_sizes:
        print("\nMost common distances between potential record starts:")
        for size, count in common_sizes:
            print(f"Size: {size:,} bytes, Count: {count}")
    
    # Show sample of dates found
    if stats['date_patterns']:
        print("\nSample of potential dates found:")
        for offset, desc in sorted(stats['date_patterns'])[:10]:
            print(f"Offset {offset:,} ({offset:08x}): {desc}")
    
    # Show sample of text regions
    print("\nSample of text regions that might contain genealogical data:")
    genealogy_keywords = ['birth', 'death', 'name', 'date', 'place', 'family', 'married']
    shown = 0
    for region in stats['text_regions']:
        if any(word in region['text'].lower() for word in genealogy_keywords):
            print(f"Offset {region['offset']:,} ({region['offset']:08x}): {region['text']}")
            shown += 1
            if shown >= 10:
                break
    
    return stats

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <binary_file>")
        sys.exit(1)
        
    filepath = sys.argv[1]
    analyze_binary_file(filepath)