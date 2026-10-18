#!/usr/bin/env python3
"""Compile production secret comparisons and HTTP/WS auth paths, without a GUI."""
from pathlib import Path
import os
import subprocess
import tempfile

ROOT = Path(os.environ.get('DORA_ENGINE_ROOT', Path.cwd())).resolve()


def harness(source):
    def section(begin, end):
        start = source.index(begin)
        return source[start:source.index(end, start)]

    helper = section('static bool constant_time_equal', 'static bool has_valid_auth')
    return r'''
#include "Source/Http/XrtNetwork.h"
#define FMT_HEADER_ONLY
#include "Source/3rdParty/fmt/format.h"
#include <algorithm>
#include <chrono>
#include <cctype>
#include <cstdlib>
#include <cstdio>
#include <memory>
#include <mutex>
#include <optional>
#include <string>
#include <string_view>
#include <unordered_map>
#include <vector>
using namespace std::string_literals;
using namespace std::string_view_literals;
#define s_cast static_cast
struct Slice : std::string {
 using std::string::string;
 Slice(std::string text):std::string(std::move(text)){}
 std::string toString()const{return *this;}
};
using String=Slice;
static Slice operator""_slice(const char* data,size_t size){return Slice(std::string(data,size));}
struct HttpServer {
 struct Request { Slice method="POST",path="/ping",contentType="application/json",body="{}";std::vector<Slice> headers,params; };
 std::string _authToken,_authSessionId,_authSessionSecret;
 bool _authTokenHasExpiry=false;
 std::chrono::steady_clock::time_point _authTokenExpiry;
 static constexpr int AuthTokenTTLSeconds=43200,AuthSignatureTTLSeconds=60;
 std::unordered_map<std::string,std::chrono::steady_clock::time_point> _authNonces;
 std::mutex _authNonceMutex;
 bool isAuthorized(const Request&);
 bool isTokenValid(const std::string&);
 bool isWebSocketAuthorized(const std::string&);
 void token(std::string value){_authToken=value;_authSessionId.clear();_authSessionSecret.clear();_authNonces.clear();}
 void session(){token("fixture:fixture-secret");_authSessionId="fixture";_authSessionSecret="fixture-secret";}
};
''' + section('static std::string get_query_param', 'static Dictionary* makeAppWSMessage') + helper.replace('constant_time_equal(', 'production_equal(') + r'''
static int comparisons=0;
static bool constant_time_equal(std::string_view a,std::string_view b){++comparisons;return production_equal(a,b);}
''' + section('static std::optional<Slice> find_header', 'static bool constant_time_equal') + section('static bool has_valid_auth', 'static void set_response') + section('bool HttpServer::isAuthorized(', '\nvoid HttpServer::post(') + r'''
static int checks=0;
static void check(bool ok,const char* label){if(!ok){std::fprintf(stderr,"FAIL: %s\n",label);std::exit(1);}++checks;}
static void decision(bool actual,bool expected,const char* label){check(actual==expected,label);check(comparisons>0,"secret comparison must use hardened helper");comparisons=0;}
int main(){
 struct{std::string a,b;bool equal;} cases[]={
 {"","",true},{"token","token",true},{"token","tokem",false},
 {"token","tokens",false},{"tokens","token",false},{"","x",false},{"x","",false},
 {std::string("a\0b",3),std::string("a\0b",3),true},
 {std::string("a\0b",3),std::string("a\0c",3),false},
 {"session:secret","session:secret",true},{"session:secret","session:secreu",false},
 {"token","uoken",false},{"token","tpken",false},{std::string(1,'\xff'),std::string(1,'\x7f'),false}};
 for(const auto& c:cases)check(production_equal(c.a,c.b)==c.equal,"helper equality");
 HttpServer server;server.token("fixture-secret");
 for(const auto& form:std::vector<std::pair<std::string,std::string>>{{"X-Dora-Auth",""},{"Authorization",""},{"Authorization","Bearer "},{"Authorization","Dora "},{"query",""}}){
  for(const auto& token:{"fixture-secret","fixture-secreu","gixture-secret","short"}){
   HttpServer::Request req;
   if(form.first=="query")req.params={"auth",token};else req.headers={Slice(form.first),Slice(form.second+token)};
   comparisons=0;decision(server.isAuthorized(req),std::string(token)=="fixture-secret","HTTP legacy auth");
  }
 }
 for(const auto& token:{"fixture-secret","fixture-secreu","short"}){
  comparisons=0;decision(server.isWebSocketAuthorized("/?auth="s+token),std::string(token)=="fixture-secret","WS legacy auth");
 }
 auto timestamp=std::to_string(std::chrono::duration_cast<std::chrono::seconds>(std::chrono::system_clock::now().time_since_epoch()).count());
 auto http=[&](std::string nonce){HttpServer::Request req;
  auto sig=hmac_sha256_hex("fixture-secret","fixture\nPOST\n/ping\n"+timestamp+"\n"+nonce+"\n"+sha256_hex("{}"));
  req.headers={"X-Dora-Session","fixture","X-Dora-Timestamp",Slice(timestamp),"X-Dora-Nonce",Slice(nonce),"X-Dora-Signature",Slice(sig)};return req;};
 auto websocket=[&](std::string nonce){auto path="/?nonce="+nonce+"&session=fixture&ts="+timestamp;
  return path+"&sig="+hmac_sha256_hex("fixture-secret","fixture\nGET\n"+path+"\n"+timestamp+"\n"+nonce+"\n");};
 server.session();auto req=http("http-replay");comparisons=0;
 decision(server.isAuthorized(req),true,"HTTP HMAC accepted");decision(server.isAuthorized(req),false,"HTTP replay rejected");
 auto target=websocket("ws-replay");decision(server.isWebSocketAuthorized(target),true,"WS HMAC accepted");decision(server.isWebSocketAuthorized(target),false,"WS replay rejected");
 for(size_t position:{size_t(0),size_t(31),size_t(63)}){
  auto nonce="http-bad-"+std::to_string(position);req=http(nonce);auto valid=req;
  req.headers.back()[position]=req.headers.back()[position]=='0'?'1':'0';
  decision(server.isAuthorized(req),false,"HTTP incorrect HMAC");decision(server.isAuthorized(valid),true,"invalid HTTP signature must not consume nonce");
  target=websocket("ws-bad-"+std::to_string(position));auto bad=target;auto start=bad.find("&sig=")+5;
  bad[start+position]=bad[start+position]=='0'?'1':'0';
  decision(server.isWebSocketAuthorized(bad),false,"WS incorrect HMAC");decision(server.isWebSocketAuthorized(target),true,"invalid WS signature must not consume nonce");
 }
 req=http("http-short");auto valid=req;req.headers.back()="short";
 decision(server.isAuthorized(req),false,"HTTP short signature rejected");decision(server.isAuthorized(valid),true,"HTTP nonce retained after short signature");
 target=websocket("ws-short");auto bad=target.substr(0,target.find("&sig=")+5)+"short";
 decision(server.isWebSocketAuthorized(bad),false,"WS short signature rejected");decision(server.isWebSocketAuthorized(target),true,"WS nonce retained after short signature");
 std::printf("Production HTTP/WS secret comparisons: %d checks passed\n",checks);
}
'''


def main():
    source = (ROOT / 'Source/Http/HttpServer.cpp').read_text()
    with tempfile.TemporaryDirectory(prefix='dora-constant-time-') as folder:
        temporary = Path(folder)
        cpp, obj, binary = temporary / 'auth.cpp', temporary / 'xrt.o', temporary / 'auth'
        cpp.write_text(harness(source))
        subprocess.run([os.environ.get('CC', 'cc'), '-std=c11', '-pthread', '-I', str(ROOT / 'Source'), '-I', str(ROOT / 'Source/3rdParty'),
                        '-c', str(ROOT / 'Source/Http/XrtNetwork.c'), '-o', str(obj)], check=True, timeout=90)
        for optimization in ('-O0', '-O2'):
            subprocess.run([os.environ.get('CXX', 'c++'), '-std=c++17', optimization, '-pthread', '-I', str(ROOT),
                            str(cpp), str(obj), '-lm', '-o', str(binary)], check=True, timeout=90)
            subprocess.run([str(binary)], check=True, timeout=15)
        print('PASS: debug/optimized production auth decisions use hardened comparisons; HTTP/WS invalid signatures and replay rejected')


if __name__ == '__main__':
    main()
