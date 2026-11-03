import Player = require('GodotPlayer');
import {Node} from 'Dora';
const player=Player(Node());
player.switchAsync('game', {buffers:3}, (ok,game,error) => {
    if (game) game.unloadAsync((done,message) => { const result:boolean=done; const detail:string=message; });
});
player.unloadAsync((ok,game,error) => {});
player.closeAsync((ok,error) => {});
