import json,math
LON0,LON1,LAT0,LAT1=21.5,46.0,44.0,53.0
PAD=0.6
BX0,BX1,BY0,BY1=LON0-PAD,LON1+PAD,LAT0-PAD,LAT1+PAD
def dp(pts,tol):
    if len(pts)<3: return pts
    stack=[(0,len(pts)-1)];keep=[False]*len(pts);keep[0]=keep[-1]=True
    while stack:
        a,b=stack.pop();ax,ay=pts[a];bx,by=pts[b];dx,dy=bx-ax,by-ay;L=math.hypot(dx,dy) or 1e-12
        mi,md=-1,0
        for i in range(a+1,b):
            px,py=pts[i];d=abs(dy*(px-ax)-dx*(py-ay))/L
            if d>md: md,mi=d,i
        if md>tol: keep[mi]=True;stack+= [(a,mi),(mi,b)]
    return [p for p,k in zip(pts,keep) if k]
def dpr(r,tol):
    if len(r)<8: return r
    m=len(r)//2
    return dp(r[:m+1],tol)[:-1]+dp(r[m:],tol)
def clip(ring):
    def cl(pts,inside,inter):
        out=[]
        for i in range(len(pts)):
            c,p=pts[i],pts[i-1]
            if inside(c):
                if not inside(p): out.append(inter(p,c))
                out.append(c)
            elif inside(p): out.append(inter(p,c))
        return out
    def ix(x):
        return lambda p,c:(x,p[1]+(c[1]-p[1])*(x-p[0])/(c[0]-p[0]))
    def iy(y):
        return lambda p,c:(p[0]+(c[0]-p[0])*(y-p[1])/(c[1]-p[1]),y)
    r=ring
    for ins,it in [(lambda p:p[0]>=BX0,ix(BX0)),(lambda p:p[0]<=BX1,ix(BX1)),(lambda p:p[1]>=BY0,iy(BY0)),(lambda p:p[1]<=BY1,iy(BY1))]:
        if not r: break
        r=cl(r,ins,it)
    return r
def rnd(pts): return [[round(x,3),round(y,3)] for x,y in pts]
def polys(geom):
    if geom['type']=='Polygon': return [geom['coordinates']]
    if geom['type']=='MultiPolygon': return geom['coordinates']
    return []
def lines(geom):
    if geom['type']=='LineString': return [geom['coordinates']]
    if geom['type']=='MultiLineString': return geom['coordinates']
    return []
def inb(pts): return any(BX0<=x<=BX1 and BY0<=y<=BY1 for x,y in pts)
out={}
# countries
C={}
for f in json.load(open('ne_50m_admin_0_countries.geojson'))['features']:
    a3=f['properties']['ADM0_A3']
    rings=[]
    for poly in polys(f['geometry']):
        outer=[tuple(p[:2]) for p in poly[0]]
        if not inb(outer): 
            # could still cover bbox fully (Russia) - check bbox overlap
            xs=[p[0] for p in outer];ys=[p[1] for p in outer]
            if max(xs)<BX0 or min(xs)>BX1 or max(ys)<BY0 or min(ys)>BY1: continue
        r=clip(outer)
        if len(r)<3: continue
        r=dpr(r,0.012)
        if len(r)>=3: rings.append(rnd(r))
    if rings: C[a3]=rings
out['countries']=C
print('countries',{k:sum(len(r) for r in v) for k,v in C.items()})
# rivers
R=[]
for f in json.load(open('ne_10m_rivers_lake_centerlines.geojson'))['features']:
    p=f['properties']; sr=p.get('scalerank',9)
    if sr>8: continue
    for ln in lines(f['geometry']):
        pts=[tuple(q[:2]) for q in ln]
        if not inb(pts): continue
        s=dp(pts,0.012)
        if len(s)>=2: R.append({'w':max(1,9-sr),'n':p.get('name') or '','p':rnd(s)})
out['rivers']=R
print('rivers',len(R),sum(len(r['p']) for r in R))
# lakes
L=[]
for f in json.load(open('ne_10m_lakes.geojson'))['features']:
    p=f['properties']
    nm=(p.get('name') or '')
    if 'Kakhov' in nm: continue
    for poly in polys(f['geometry']):
        outer=[tuple(q[:2]) for q in poly[0]]
        if not inb(outer): continue
        xs=[q[0] for q in outer];ys=[q[1] for q in outer]
        if (max(xs)-min(xs))*(max(ys)-min(ys))<0.004: continue
        s=dpr(outer,0.01)
        if len(s)>=3: L.append({'n':nm,'p':rnd(s)})
out['lakes']=L
print('lakes',len(L),[l['n'] for l in L])
# admin1 lines
A=[]
for f in json.load(open('adm1.geojson'))['features']:
    p=f['properties']
    if p.get('ADM0_A3') not in ('UKR','RUS','BLR'): continue
    for ln in lines(f['geometry']):
        pts=[tuple(q[:2]) for q in ln]
        if not inb(pts): continue
        s=dp(pts,0.015)
        if len(s)>=2: A.append(rnd(s))
out['adm1']=A
print('adm1',len(A),sum(len(a) for a in A))
s=json.dumps(out,separators=(',',':'))
open('geo.json','w').write(s)
print('bytes',len(s))
