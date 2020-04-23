ACTIVATED_BUTTON = "rgb(1,0.6,1)|rgb(1,0.4,1)|rgb(1,0.2,1)|rgb(1,0.2,1)"
DEFAULT_BUTTON = "#FFFFFF|#FFFFFF|#C8C8C8|rgba(0.78,0.78,0.78,0.5)"
prodServerURL = "https://backend.battlescribe2tts.net"
serverURL = prodServerURL
version = "1.5"

nextModelTarget = ""
nextModelButton = ""
modelPickedUp = false
modelData = {}
modelWidths = {}
descriptorMapping = {}
code = ""
rosterMapping = {}
buttonMapping = {}
storedDataMapping = {}
createArmyLock = false

function onScriptingButtonDown(index, peekerColor)
  local player = Player[peekerColor]
  if index == 1 and player.getHoverObject() and player.getHoverObject().getGUID() == self.getGUID() then
    broadcastToAll("Activating Development Mode")
    serverURL = "http://localhost:8080"
  end
  if index == 2 and player.getHoverObject() and player.getHoverObject().getGUID() == self.getGUID() then
    broadcastToAll("Activating Production Mode")
    serverURL = prodServerURL
  end
end

function tempLock()
  self.setLock(true)
  local this = self
  Wait.time(
    function()
      this.setLock(false)
    end,
    3
  )
end

function onLoad()
  local contained = self.getObjects()
  for k, v in pairs(contained) do
    local name = v.name
    local data = JSON.decode(v.description)
    rosterMapping[name] = data.json
    descriptorMapping[name] = data.descriptor
    storedDataMapping[name] = v.guid
  end
  checkVersion()
  Wait.time(announce, 4)
end

function announce()
  broadcastToAll("Thanks for using Battlescribe Army Creator! Go to https://battlescribe2tts.net for instructions")
end

function checkVersion()
  WebRequest.get(serverURL .. "/version", verifyVersion)
end

function verifyVersion(req)
  if req and req.text then
    local json = JSON.decode(req.text)
    if json and json.id then
      local remoteVersion = json.id
      if remoteVersion ~= version then
        Wait.time(
          function()
            broadcastToAll(
              "You are using an out-of-date version of Battlescribe Army Creator. " ..
                "Get the latest version from the workshop!"
            )
          end,
          3
        )
      end
    end
  end
end

function setModel(player, value, id)
  nextModelTarget = self.UI.getAttribute(id, "modelName")
  local shortName = self.UI.getAttribute(id, "shortName")
  nextModelButton = id
  broadcastToAll("Pick up an object to set it as the model for " .. shortName)
end

function onObjectPickUp(colorName, obj)
  if nextModelTarget ~= "" then
    modelPickedUp = true
    obj.highlightOn({1, 0, 1}, 5)
    local bounds = obj.getBoundsNormalized()
    local width = math.max(bounds.size.x, bounds.size.z) * 1.2
    local copy = JSON.decode(obj.getJSON())
    copy.Nickname = nextModelTarget
    copy.States = nil
    copy.Width = width
    table.insert(modelData, copy)
    table.insert(modelWidths, width)
  end
end

function onUpdate()
  if modelPickedUp then
    self.UI.setAttribute(nextModelButton, "colors", ACTIVATED_BUTTON)

    local data = {
      name = nextModelTarget,
      descriptor = descriptorMapping[nextModelTarget],
      json = modelData,
      width = modelWidths
    }
    local jsonData = JSON.encode(data)
    local this = self
    spawnObject(
      {
        type = "Notecard",
        callback_function = function(spawned)
          spawned.setVar("bs2tts-allowed", "true")
          spawned.setName(data.name)
          spawned.setDescription(jsonData)
          this.putObject(spawned)
        end
      }
    )
    nextModelTarget = ""
    nextModelButton = ""
    modelPickedUp = false
    modelData = {}
    modelWidths = {}
  end
end

function filterObjectEnter(obj)
  return obj.getVar("bs2tts-allowed") == true
end

function onObjectLeaveContainer(thisContainer, takenObject)
  if thisContainer.getGUID() == self.getGUID() then
    tempLock()
    local name = takenObject.getName()
    rosterMapping[name] = nil
    storedDataMapping[name] = nil
    if buttonMapping[name] ~= nil then
      thisContainer.UI.setAttribute(buttonMapping[name], "colors", DEFAULT_BUTTON)
    end
  end
end

function onObjectEnterContainer(thisContainer, addedObject)
  if thisContainer.getGUID() == self.getGUID() then
    tempLock()
    local name = addedObject.getName()
    local data = JSON.decode(addedObject.getDescription())
    if storedDataMapping[name] ~= nil then
      self.takeObject(
        {
          guid = storedDataMapping[name],
          callback_function = function(obj)
            obj.destruct()
          end
        }
      )
    end
    descriptorMapping[name] = data.descriptor
    rosterMapping[name] = data.json
    storedDataMapping[name] = addedObject.guid
    if buttonMapping[name] ~= nil then
      thisContainer.UI.setAttribute(buttonMapping[name], "colors", ACTIVATED_BUTTON)
    end
  end
end

function setCode(player, value, id)
  code = value
end

function getCode()
  return code
end

function submitCode(player, value, id)
  if player.host then
    WebRequest.get(serverURL .. "/roster/" .. getCode() .. "/names", processNames)
  else
    broadcastToAll("Sorry, only the host of this game may use the Battlescribe Army Creator")
  end
end

function tabToS(tab)
  local s = "{"
  for k, v in pairs(tab) do
    s = s .. k .. "=" .. tostring(v) .. ","
  end
  s = s .. "}"
  return s
end

function processNames(webReq)
  tempLock()
  if not webReq or webReq.error or webReq.is_error then
    broadcastToAll("Error in web request: No such roster or server error")
    return
  end
  local response = JSON.decode(webReq.text)
  local buttonNames = {}
  local shortNames = {}
  for k, v in pairs(response.modelsRequested) do
    local weapons = ""
    for k, v in pairs(v.modelWeapons) do
      if weapons ~= "" then
        weapons = weapons .. ", "
      end
      weapons = weapons .. v
    end
    local name = "Model: " .. v.modelName .. "\nWeapons: " .. weapons
    table.insert(buttonNames, name)
    shortNames[name] = v.modelName
    descriptorMapping[name] = v
  end
  local zOffset = -3
  local xOffset = 3
  local vectors = {}
  local index = 0
  local newButtons = {}
  local heightInc = 220
  local widthInc = 820
  local colHeight = 10
  for k, v in pairs(buttonNames) do
    local buttonColor = DEFAULT_BUTTON
    if rosterMapping[v] ~= nil then
      buttonColor = ACTIVATED_BUTTON
    end
    local buttonId = "select " .. v .. " " .. index
    buttonMapping[v] = buttonId
    table.insert(
      newButtons,
      {
        tag = "Button",
        attributes = {
          id = buttonId,
          onClick = "setModel",
          modelName = v,
          shortName = shortNames[v],
          padding = 20,
          colors = buttonColor,
          fontSize = 50,
          height = heightInc,
          width = widthInc,
          offsetXY = widthInc * (math.floor(index / colHeight)) .. " " .. -1 * heightInc * (index % colHeight)
        },
        value = v
      }
    )
    index = index + 1
  end
  local panel = {
    tag = "Panel",
    attributes = {
      width = widthInc * ((#buttonNames / colHeight) + 1),
      height = heightInc * colHeight,
      position = "1300 0 -300"
    },
    children = newButtons
  }
  local currentUI = self.UI.getXmlTable()
  self.UI.setXmlTable({currentUI[1], panel})
  self.setVectorLines(vectors)
end

function spawnModelRecur(id, threads, limit, index)
  if index < limit then
    WebRequest.get(
      serverURL .. "/v2/roster/" .. id .. "/" .. index,
      function(req)
        if req and req.text then
          local v = JSON.decode(req.text)
          local relPos = v.Transform
          local thisPos = self.getPosition()
          local adjustedPos = {
            x = thisPos.x + relPos.posX - 20,
            y = thisPos.y + relPos.posY + 4,
            z = thisPos.z + relPos.posZ
          }
          local jv = JSON.encode(v)
          spawnObjectJSON(
            {
              json = jv,
              position = adjustedPos
            }
          )
          spawnModelRecur(id, threads, limit, index + 1)
        else
          broadcastToAll("Error requesting model " .. index)
        end
      end
    )
  else
    spawnThreadCounter = spawnThreadCounter + 1
    if spawnThreadCounter >= threads then
      broadcastToAll("Army creation complete!")
    end
  end
end

spawnThreadCounter = 0

function createArmy(player, value, id)
  if player.host then
    if not createArmyLock then
      spawnThreadCounter = 0
      tempLock()
      createArmyLock = true
      Wait.time(
        function()
          createArmyLock = false
          self.UI.setAttribute(id, "interactable", "true")
        end,
        5
      )
      self.UI.setAttribute(id, "interactable", "false")
      mappingResponse = {modelAssignments = {}}
      for name, json in pairs(rosterMapping) do
        local assignment = {
          modelJSON = json,
          descriptor = descriptorMapping[name]
        }
        table.insert(mappingResponse.modelAssignments, assignment)
      end
      local jsonToSend = JSON.encode(mappingResponse)
      broadcastToAll("Contacting Server (this may take a minute or two)...")
      WebRequest.put(
        serverURL .. "/v2/roster/" .. getCode(),
        jsonToSend,
        function(req)
          broadcastToAll("Loading Models...")
          if not req or req.is_error then
            broadcastToAll("Error in web request")
          end
          local status, result =
            pcall(
            function()
              return JSON.decode(req.text)
            end
          )
          if status then
            local response = JSON.decode(req.text)
            local itemsToSpawn = response.itemCount
            local groupsOf = 10
            for i = 0, (itemsToSpawn / groupsOf), 1 do
              local start = i * groupsOf
              spawnModelRecur(getCode(), (itemsToSpawn / groupsOf), math.min(start + groupsOf, itemsToSpawn), start)
            end
          else
            broadcastToAll("Got error: " .. req.text, {r = 1, g = 0, b = 0})
          end
        end
      )
    end
  else
    broadcastToAll("Sorry, only the host of this game may use the Battlescribe Army Creator")
  end
end
