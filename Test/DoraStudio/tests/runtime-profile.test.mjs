import test from 'node:test';
import assert from 'node:assert/strict';
import {validateGameRuntimeProfile} from '../apps/web/scripts/runtime-profile.mjs';
test('trusted Agent host artifacts cannot be published through game runtime staging',()=>{
  const profile={activeProfile:'dora-preset',modules:{threads:true,crossOriginIsolationRequired:true}};
  assert.doesNotThrow(()=>validateGameRuntimeProfile(profile));
  assert.doesNotThrow(()=>validateGameRuntimeProfile({...profile,studioAgentHost:false}));
  assert.throws(()=>validateGameRuntimeProfile({...profile,studioAgentHost:true}),/cannot be staged/);
  assert.throws(()=>validateGameRuntimeProfile({...profile,studioAgentHost:'false'}),/Invalid/);
  assert.throws(()=>validateGameRuntimeProfile({...profile,modules:{threads:false}}),/pthread/);
});
