#!/usr/bin/env python3
"""Import an inspected, privately staged Zotero inventory; never writes to Zotero."""
import argparse, hashlib, json, os, pathlib, re, shlex, time, urllib.error, urllib.parse, urllib.request, uuid, zipfile

os.umask(0o077)

def save(path, value):
    temp = path.with_suffix('.partial')
    temp.write_text(json.dumps(value, indent=2, ensure_ascii=False))
    temp.replace(path)

class API:
    def __init__(self):
        envpath = pathlib.Path.home()/'.config/karakeep/api.env'
        if envpath.stat().st_mode & 0o077:
            raise RuntimeError('api.env must be private')
        env = {}
        for line in envpath.read_text().splitlines():
            line = line.strip().removeprefix('export ')
            if not line or line.startswith('#'): continue
            key, value = line.split('=', 1)
            env[key] = ''.join(shlex.split(value))
        self.base = env['KARAKEEP_SERVER_ADDR'].rstrip('/')+'/api/v1'
        self.key = env['KARAKEEP_API_KEY']
    def request(self, path, method='GET', data=None, mime='application/json', raw=False):
        if data is not None and not isinstance(data, bytes): data=json.dumps(data).encode()
        req=urllib.request.Request(self.base+path, data=data, method=method,
            headers={'Authorization':'Bearer '+self.key, 'Content-Type':mime})
        try:
            with urllib.request.urlopen(req, timeout=180) as res:
                body=res.read()
                return body if raw else json.loads(body) if body else None
        except urllib.error.HTTPError as e:
            # API response can contain private content; retain locally, never credentials.
            raise RuntimeError(f'{method} {path.split("?")[0]}: HTTP {e.code}: {e.read().decode()[:600]}') from None
    def upload(self, content, filename, mime):
        boundary='zotero'+uuid.uuid4().hex
        filename=re.sub(r'[^a-zA-Z0-9._-]', '_', filename)
        data=(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{filename}"\r\nContent-Type: {mime}\r\n\r\n').encode()+content+f'\r\n--{boundary}--\r\n'.encode()
        return self.request('/assets','POST',data,'multipart/form-data; boundary='+boundary)
    def bookmarks(self):
        out=[];cursor=None
        while True:
            result=self.request('/bookmarks?'+urllib.parse.urlencode({'limit':100,**({'cursor':cursor} if cursor else {})}))
            out.extend(result['bookmarks']);cursor=result.get('nextCursor')
            if not cursor:return out

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--state-dir',type=pathlib.Path,required=True)
    p.add_argument('--execute',action='store_true',help='Import after reviewing the inventory.')
    p.add_argument('--validate',action='store_true',help='Read back imported records/assets only.')
    args=p.parse_args();root=args.state_dir;inv=json.loads((root/'inventory.json').read_text());downloads=json.loads((root/'downloads.json').read_text())
    items={i['data']['key']:i['data'] for i in inv['items']};cols={c['data']['key']:c['data'] for c in inv['collections']}
    receipt_path=root/'receipt.json';state=json.loads(receipt_path.read_text()) if receipt_path.exists() else {'items':{},'assets':{},'lists':{}}
    def persist():save(receipt_path,state)
    attachments={k:d for k,d in items.items() if d['itemType']=='attachment'}
    sources={k:d for k,d in items.items() if d['itemType']!='attachment' or d.get('contentType')=='application/pdf' or d.get('contentType','').startswith('image/')}
    snapshots={d.get('parentItem'):k for k,d in attachments.items() if d.get('contentType')=='text/html'}
    summary={'zoteroItems':len(items),'sourceBookmarks':len(sources),'attachments':len(attachments),'collections':len(cols),'downloadFailures':[k for k,v in downloads.items() if 'error' in v]}
    if not args.execute and not args.validate:
        print(json.dumps(summary,indent=2));return
    api=API()
    identity=api.request('/users/me')
    if identity.get('email') != 'carlos@disusered.com':raise RuntimeError('Unexpected Karakeep account; stopping before writes')
    def marker(k):return f'[Zotero users/{inv["userId"]}/items/{k}]'
    def blob(k):
        dl=downloads[k];content=pathlib.Path(dl['path']).read_bytes()
        if hashlib.sha256(content).hexdigest()!=dl['sha256']:raise RuntimeError('Staged file checksum mismatch: '+k)
        d=items[k];filename=d.get('filename') or k
        if dl.get('zip'):
            with zipfile.ZipFile(dl['path']) as z:
                entries=[n for n in z.namelist() if not n.endswith('/')]
                if len(entries)!=1 or not entries[0].lower().endswith(('.html','.htm')):raise RuntimeError('Snapshot requires multi-file conversion: '+k)
                filename=pathlib.PurePosixPath(entries[0]).name;content=z.read(entries[0])
        return content,filename,d.get('contentType','application/octet-stream')
    def asset(k):
        if k not in state['assets']:
            content,filename,mime=blob(k);uploaded=api.upload(content,filename,mime)
            state['assets'][k]={**uploaded,'sha256':hashlib.sha256(content).hexdigest()};persist()
        return state['assets'][k]['assetId']
    if args.execute:
        existing=api.bookmarks()
        lists=api.request('/lists')['lists']
        def ensure_list(k):
            if k in state['lists']:return state['lists'][k]
            d=cols[k];description=f'Imported Zotero collection users/{inv["userId"]}/collections/{k}'
            found=next((l for l in lists if l.get('description')==description),None)
            if not found:
                payload={'name':d['name'][:100],'description':description,'icon':'📚','type':'manual'}
                if d.get('parentCollection'):payload['parentId']=ensure_list(d['parentCollection'])
                found=api.request('/lists','POST',payload);lists.append(found)
            state['lists'][k]=found['id'];persist();return found['id']
        for k in cols:ensure_list(k)
        for k,d in sources.items():
            try:
                url=d.get('url');snapshot=snapshots.get(k)
                metadata=[d]+([items[snapshot]] if snapshot else [])
                provenance=marker(k)+'\n'+f'https://www.zotero.org/users/{inv["userId"]}/items/{k}'+'\n\nOriginal Zotero metadata:\n```json\n'+json.dumps(metadata,indent=2,ensure_ascii=False)+'\n```'
                bid=state['items'].get(k,{}).get('bookmarkId')
                found=next((b for b in existing if marker(k) in (b.get('note') or '')),None)
                if not bid and found:bid=found['id']
                if not bid and d['itemType']!='attachment' and url:
                    bid=api.request('/bookmarks/check-url?'+urllib.parse.urlencode({'url':url}))['bookmarkId']
                reused=bool(bid)
                if not bid:
                    payload={'title':d.get('title','')[:1000],'note':provenance,'source':'import'}
                    if d.get('dateAdded'):payload['createdAt']=d['dateAdded']
                    if d['itemType']=='attachment':
                        payload.update(type='asset',assetType='pdf' if d['contentType']=='application/pdf' else 'image',assetId=asset(k),fileName=d.get('filename') or k)
                        if url:payload['sourceUrl']=url
                    elif url:
                        payload.update(type='link',url=url)
                        if snapshot:payload['precrawledArchiveId']=asset(snapshot)
                    else:payload.update(type='text',text=d.get('note') or json.dumps(d,ensure_ascii=False))
                    found=api.request('/bookmarks','POST',payload);bid=found['id'];existing.append(found)
                state['items'][k]={'bookmarkId':bid,'reused':reused,'status':'created'};persist()
                current=api.request('/bookmarks/'+bid)
                if marker(k) not in (current.get('note') or ''):
                    api.request('/bookmarks/'+bid,'PATCH',{'note':(current.get('note') or '')+'\n\n'+provenance})
                if snapshot:
                    aid=asset(snapshot)
                    if not any(a['id']==aid for a in current.get('assets',[])):
                        api.request('/bookmarks/'+bid+'/assets','POST',{'id':aid,'assetType':'userUploaded'})
                tags=sorted({t['tag'] for m in metadata for t in m.get('tags',[]) if t.get('tag')})
                if tags:api.request('/bookmarks/'+bid+'/tags','POST',{'tags':[{'tagName':t,'attachedBy':'human'} for t in tags]})
                memberships=set(d.get('collections',[]))
                if d.get('parentItem') in items:memberships.update(items[d['parentItem']].get('collections',[]))
                for ck in memberships:api.request('/lists/'+ensure_list(ck)+'/bookmarks/'+bid,'PUT')
                state['items'][k].update(status='imported',collections=sorted(memberships),tags=tags)
                state['items'][k].pop('error', None)
                state.setdefault('records', {}).setdefault(k, {}).update({'metadata':d,'bookmarkId':bid,'role':'source','status':'imported'})
                if snapshot:
                    state['records'].setdefault(snapshot, {}).update({'metadata':items[snapshot],'bookmarkId':bid,'parentZoteroKey':k,'assetId':state['assets'][snapshot]['assetId'],'role':'snapshot','status':'imported'})
                persist()
                print('Imported '+k,flush=True)
            except Exception as e:
                state['items'].setdefault(k,{})['error']=str(e);persist();print('Failed '+k+' (private receipt has details)',flush=True)
        args.validate=True
    if args.validate:
        results={};asset_checks={}
        for k,r in state['items'].items():
            if not r.get('bookmarkId'):continue
            try:
                b=api.request('/bookmarks/'+r['bookmarkId']+'?includeContent=true');c=b['content']
                content=api.request('/bookmarks/'+b['id']+'/content?format=text&maxChars=50000')
                memberships=api.request('/bookmarks/'+b['id']+'/lists')
                results[k]={'bookmarkId':b['id'],'type':c['type'],'crawlStatus':c.get('crawlStatus'),'textChars':len(content.get('content') or ''),'fullPageArchiveAssetId':c.get('fullPageArchiveAssetId'),'precrawledArchiveAssetId':c.get('precrawledArchiveAssetId'),'metadataPresent':marker(k) in (b.get('note') or ''),'tags':[t.get('name') for t in b.get('tags',[])],'lists':memberships,'assets':b.get('assets',[])}
                save(root/('readback-'+k+'.json'),{'bookmark':b,'content':content})
            except Exception as e:results[k]={'error':str(e)}
        for k,a in state['assets'].items():
            try:
                data=api.request('/assets/'+a['assetId'],raw=True)
                asset_checks[k]={'assetId':a['assetId'],'bytes':len(data),'sha256Matches':hashlib.sha256(data).hexdigest()==a['sha256']}
            except Exception as e:asset_checks[k]={'error':str(e)}
        save(root/'validation.json',{'items':results,'uploadedAssets':asset_checks})
        print(json.dumps({'readbacks':len(results),'errors':sum('error' in r for r in results.values()),'uploadedAssetsVerified':sum(r.get('sha256Matches',False) for r in asset_checks.values()),'crawlStatuses':{v:sum(r.get('crawlStatus')==v for r in results.values()) for v in ['success','pending','failure',None]},'nonemptyExtraction':sum(r.get('textChars',0)>0 for r in results.values()),'fullPageArchives':sum(bool(r.get('fullPageArchiveAssetId')) for r in results.values()),'preservedSnapshots':sum(bool(r.get('precrawledArchiveAssetId')) for r in results.values())},indent=2))

if __name__=='__main__':main()
