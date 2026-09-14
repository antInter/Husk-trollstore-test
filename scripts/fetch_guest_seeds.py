#!/usr/bin/env python3
"""Fetch only guest disk seeds from pinned upstream Husk 0.2.0, never executable code."""
import argparse, hashlib, io, struct, urllib.request, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
URL='https://github.com/Leviidev/Husk/releases/download/0.2.0/Husk.ipa'
IPA_SHA='f504295acce2d2cbedf9f28de056b149fe692552c6f6e5d38c9cc122f0a82585'
SEEDS={
 'lineage-efi-vars-seed.fd':(334848,67108864,'f5b7f83db14d73152824a5d79f8f42050c4ed196705a0e759730f43a2ec13f23'),
 'lineage-vdb-seed.qcow2':(196864,17179869184,'de001102cbc8ff7aa8eb6c69d750cf22b94104935a0de6277ec5f24509927745')}
def validate(name,data):
 length,virtual,sha=SEEDS[name]
 if len(data)!=length or hashlib.sha256(data).hexdigest()!=sha:
  raise ValueError('Seed size/SHA-256 mismatch: '+name)
 if data[:4]!=b'QFI\xfb' or struct.unpack_from('>I',data,4)[0]!=3 or struct.unpack_from('>Q',data,24)[0]!=virtual or struct.unpack_from('>Q',data,8)[0]!=0:
  raise ValueError('Invalid QCOW2 seed: '+name)
def verify(directory):
 for name in SEEDS:
  validate(name,(directory/name).read_bytes())
  print('Verified guest seed:',name)
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--verify-only',type=Path);a=p.parse_args()
 if a.verify_only: verify(a.verify_only);return
 out=ROOT/'src/app/Husk/Resources'
 try: verify(out);return
 except (OSError,ValueError): pass
 with urllib.request.urlopen(URL,timeout=90) as response:
  data=response.read(40*1024*1024+1)
 if len(data)>40*1024*1024 or hashlib.sha256(data).hexdigest()!=IPA_SHA:
  raise ValueError('Upstream IPA checksum/size mismatch')
 contents={}
 with zipfile.ZipFile(io.BytesIO(data)) as archive:
  for name,(size,_,_) in SEEDS.items():
   member=archive.getinfo('Payload/Husk.app/'+name)
   if member.file_size!=size: raise ValueError('Unexpected member size')
   contents[name]=archive.read(member);validate(name,contents[name])
 out.mkdir(parents=True,exist_ok=True)
 for name,seed in contents.items():
  tmp=out/(name+'.part');tmp.write_bytes(seed);tmp.replace(out/name)
 verify(out)
if __name__=='__main__': main()
