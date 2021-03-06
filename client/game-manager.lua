require 'game-state'

local enet          = require "enet"
local json          = require 'utils/json'
local tlm           = require 'utils/tile-manager'
local Renderer      = require 'utils/renderer'
local camera        = require('utils/camera')
local GameManager   = {}
local server        = {}

--globals
asm = require 'utils/asset-manager'
guiManager = require('gui')
renderer = Renderer:create()
gWidth = love.graphics.getWidth()
gHeight = love.graphics.getHeight()

-- locals
local x = 64
local y = 64
local speed = 200
local players = {}
local isConnected = false
local isCom = false
local channel = 0
local isMapSet = false
local state = GAME_STATE.MENU

function setState(newState)
    state = newState
    if state == GAME_STATE.MENU then
        isCom = false
        isConnected = false
    end
end

function GameManager:loadGame()
    setState(GAME_STATE.LOAD)
    tlm:load()
    tlm:loadMap('new-desert')    

    self.connectServer()
end

function GameManager:getState()
    return state
end

function GameManager:exit()
    love.event.push("quit")
end

function GameManager:connectServer()
    host = enet.host_create()
    server = host:connect("localhost:6789")
end

function GameManager:update(dt)    
    if server and self.getState() ~= GAME_STATE.MENU then
        if (isConnected and isCom ~= true) then
            -- print('init new player')
            pid = math.random(9999)
            host:broadcast(json.encode({x = x + (speed * dt), y = y, pid = pid}))
            isCom = true
            setState(GAME_STATE.PLAY)
        end
        local event = host:service(100)        
        local playerX = x
        local playerY = y
        if love.keyboard.isDown('d') then
            playerX = x + (speed * dt)
        end
        if love.keyboard.isDown('a') then
            playerX = x - (speed * dt)
        end
        if love.keyboard.isDown('w') then
            playerY = y - (speed * dt)
        end
        if love.keyboard.isDown('s') then
            playerY = y + (speed * dt)
        end
        
        if playerX ~= x or playerY ~= y then
            host:broadcast(json.encode({x = playerX, y = playerY, pid = pid, channel = channel}))
        end

        if event then            
            -- print('event:', event.type)
            if event.type == "receive" then
                print("Got message: ", event.channel, event.peer)
                if event.data ~= nil then
                    local data = json.decode(event.data)
                    print(data.isNew, data.pid == pid)
                    if data.isNew and data.pid == pid then
                        channel = data.channel
                    end

                    if data.channel == channel then
                        print('player is on channel')
                        players = data.players 
                    end
                end
                                
            elseif event.type == "connect" then
                print(event.peer, "connected.")
                isConnected = true
            elseif event.type == "disconnect" then
                print(event.peer, "disconnected.")
                isConnected = false
                isCom = false
                host:broadcast(pid)                
            end
            event = host:service()
        end        
    end
end

function GameManager:draw()               
    if state == GAME_STATE.MENU then
        guiManager:draw()
    end
    if state == GAME_STATE.PLAY then
        camera:set()    
        renderer:draw()
        -- TODO: move to function
        for i = 1, #players do
            local player = players[i]        
            if player.pid == pid then
                x = player.x
                y = player.y
                camera:gotoPoint({x = x, y = y})
            end
            love.graphics.circle('fill', player.x, player.y, 16, 8)    
            
        end
        camera:unset()
    end
    
    
end

function GameManager:load()
    asm:load()      
    guiManager:load()  
    asm:add(love.graphics.newImage('assets/sprites/desert.png'), "lvl1_tiles")
end

function love.keypressed(key)    
    if key == "escape" then
        -- love.event.push("quit")
        setState(GAME_STATE.MENU)
    end
end

return GameManager
