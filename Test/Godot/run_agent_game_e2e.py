"""Interactive live-provider Dora Agent test controller; never writes credentials to evidence.

Create commands/NNNN.json with {action:send,prompt:...}, {action:request,path:...,body:{...}}
 or {action:shutdown}. This uses an isolated native profile and the normal Web IDE APIs.
"""
import argparse,json,pathlib,sqlite3,sys,time,urllib.request
from contextlib import nullcontext
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]/'support'))
from native_agent import NativeAgent,add_engine_argument
from godot_paths import ENGINE_ROOT
p=argparse.ArgumentParser(description=__doc__);add_engine_argument(p)
p.add_argument('--library',type=pathlib.Path,required=True);p.add_argument('--output',type=pathlib.Path,required=True)
p.add_argument('--attach',action='store_true',help='Use the already visible local engine, leave it running and preserve its configurations')
p.add_argument('--project',type=pathlib.Path)
p.add_argument('--provider-db',type=pathlib.Path,required=True);p.add_argument('--provider-id',type=int,required=True)
a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=True);(out/'commands').mkdir(exist_ok=True)
project=a.project.resolve() if a.project else out/'game';project.mkdir(exist_ok=True)
def save(name,data):
 dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True);tmp=dest.with_suffix('.pending');tmp.write_text(json.dumps(data,ensure_ascii=False,indent=2));tmp.replace(dest)
op=urllib.request.build_opener(urllib.request.ProxyHandler({}))
def post(path,body=None):
 req=urllib.request.Request('http://127.0.0.1:8866'+path,data=json.dumps(body or {}).encode(),headers={'Content-Type':'application/json','Origin':'http://127.0.0.1:8866'})
 return json.load(op.open(req,timeout=120))
engine=NativeAgent(a.engine,ENGINE_ROOT,startup_timeout=60);engine.environment['DORA_GODOT_LIBRARY']=str(a.library.resolve())
with (nullcontext() if a.attach else engine):
 db=sqlite3.connect('file:'+str(a.provider_db.resolve())+'?mode=ro',uri=True);db.row_factory=sqlite3.Row
 columns='id,name,model' if a.attach else '*'
 row=dict(db.execute('select '+columns+' from LLMConfig where id=?',(a.provider_id,)).fetchone());db.close()
 if a.attach:
  config_id=a.provider_id
  log_path=None # Never copy historical logs from the user's profile.
 else:
  config={'name':'E2E '+row['name'],'url':row['url'],'model':row['model'],'key':row['api_key'],'contextWindow':row['context_window'],'temperature':row['temperature'],'maxTokens':row['max_tokens'],'reasoningEffort':row['reasoning_effort'],'customOptions':row['custom_options']}
  assert post('/llm/create',config)['success']
  items=post('/llm/list')['items'];config_id=next(item['id'] for item in items if item['name']==config['name'])
  save('provider.json',{'name':row['name'],'model':row['model'],'originalConfigUntouched':True})
  del config,items
  log_path=engine.log_path
 save('provider.json',{'name':row['name'],'model':row['model'],'originalConfigUntouched':True})
 del row
 created=post('/agent/session/create',{'projectRoot':str(project),'title':'Tiny Dungeon 多轮端到端测试'})
 assert created['success'],created;session_id=created['session']['id'];save('session-created.json',created)
 print('READY session='+str(session_id),flush=True)
 completed=set();round_id=0;last_summary=None;last_poll=0
 try:
  while True:
   stop=False
   for file in sorted((out/'commands').glob('*.json')):
    if file.name in completed:continue
    command=json.loads(file.read_text());action=command['action']
    if action=='shutdown':stop=True;completed.add(file.name);break
    if action=='send':
     round_id+=1
     body={'sessionId':session_id,'prompt':command['prompt'],'workMode':'code','llmConfigId':config_id,'disabledAgentTools':['spawn_sub_agent']}
     response=post('/agent/session/send',body);save(f'round-{round_id}/send.json',response)
    elif action=='request':response=post(command['path'],command.get('body'))
    else:raise ValueError('unknown action')
    save('responses/'+file.name,response);completed.add(file.name)
   if stop:break
   if time.monotonic()-last_poll>=3:
    snapshot=post('/agent/task/status',{'sessionId':session_id});save('latest.json',snapshot)
    if round_id:save(f'round-{round_id}/status.json',snapshot)
    session=snapshot.get('session',{});steps=snapshot.get('steps',[])
    last=steps[-1] if steps else {}
    summary={'round':round_id,'status':session.get('status'),'taskStatus':session.get('currentTaskStatus'),'stepCount':len(steps),'tool':last.get('tool'),'stepStatus':last.get('status'),'reason':last.get('reason','')[:350]}
    if summary!=last_summary:save('progress.json',summary);print(json.dumps(summary,ensure_ascii=False),flush=True);last_summary=summary
    last_poll=time.monotonic()
   time.sleep(.3)
 finally:
  try:save('final-session.json',post('/agent/session/get',{'sessionId':session_id}))
  except Exception as error:save('snapshot-error.json',{'type':type(error).__name__,'message':str(error)})
  if log_path is not None and log_path.exists():(out/'engine.log').write_text(log_path.read_text(errors='replace'))
  # Preserve session/task evidence, not the temporary profile's secret config DB.
  save('controller-finished.json',{'sessionId':session_id,'rounds':round_id})
