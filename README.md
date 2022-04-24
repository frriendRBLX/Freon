# Freon (beta)

A replicated state manager for Roblox.

**Freon is still in beta, so expect some issues.**

---
## Features:
- Freon is Efficient. It will only Replicate state when updated to avoid unnessesary client updates.
- Automatically pulls server state to client when a player joins.
- Data is Secure. Client is never trusted with replicated state updates.
- Freon's replication is optional. You can use Freon to create state that exists souly on the client or server.
- One module for both the server and the client. 

## Quirks:
- Freon is only able to accept primitive types within its state.
- For security, Freon's Replication is strictly downstream (Server to Client)

---
## API:

Note: The <span style="color:#ea51f5">**[Owner Only]**</span> flag denotes that the method can only be used on Objects that were created Locally (**Server Calling Server Created State** or **Client Calling Client Created State**)

<br>

> `Freon.new(Key: string, InitState: {any}, Recipients: {Player?} | Player?, IsPermanent: boolean?)` 
>
>Creates a new `Freon Instance` given an `Key` and inital `State`.
> 
> <span style="color:#ff4f6f"> **Note:** If an instance is created on the server, it will replicate to the given Recipients. Leave this empty or nil if you want Freon to replicate this state to all clients. 
></span>
>```lua 
>Freon.new("Globals", {
>    MyAwesomeKey = "MyAwesomeValue",
>    MyFavoriteNumber = 10
>}, Freon.AllPlayers, true)
>```

><span style="color:#e9ed7e">[**Yeilding**]</span>
>
>`State:await(Key: string): Freon`
>
> Waits for a `State` to replicate given a key. Returns a `Freon Instance`.
>```lua
>local State = State:await("Globals")
>```

> `State:get()` 
>
>Returns the **Current** `State` of our `Freon Instance`.
>```lua
>local Data = State:get()
>print(Data.MyFavoriteNumber)
>```

><span style="color:#ea51f5">[**Owner Only**]</span>
>
> `State:set({any})` 
>
>Completely Overwrites the State of a Freon Instance.
>```lua
>State:set({
>    MyFavoriteNumber = 10
>})
>print(State:Get().MyFavoriteNumber)
>```

><span style="color:#ea51f5">[**Owner Only**]</span>
>>
> `State:update(Key: string, Value: any)` 
>
>Update a single key within the state.
>```lua
>State:update(MyFavoriteNumber, 12)
>print(State:Get().MyFavoriteNumber)
>```
>

>
> `State:onUpdate(Callback -> (CurrentState: {any}))` 
>
>Fires when state is modified. Passes current state to Callback.
>```lua
>State:onUpdate(function(CurrentState)
>    print(CurrentState.MyFavoriteNumber)
>)
>```

---
## Things To Avoid

><span style="color:#ff4f6f">**Never**</span> attempt to modify a `Freon Instance` directly. Freon's internal state is **read only**.
>
>```lua
>-- Bad
>State.State = {"Test"}
>
>-- Good
>State:set({"Test"})
>```

><span style="color:#ff4f6f">**Never**</span> expect Client state to be accessable by the server. <span style="color:#ff4f6f">Freon is intentionally unable to replicate from Client to Server for security. Any attempt to do so will throw an error.</span>

---
## Example:
Here is an example of a simple countdown.

```lua
--> Server -->-----------------------------------
local Freon = require(game.ReplicatedStorage.Modules.Freon)

--> New State Object (Key: string, InitialValue: {any}, Recipients: {Player} | Player | boolean?, IsPermanent: boolean?)
local State = Freon.new("Globals", {
    GameTimeLeft = 10,
    PlayersLeft = 0
}, Freon.AllPlayers, true)

--> Countdown
for i = 9, 1, -1 do
    task.wait(1)
    
    --> Update State
    State:update("GameTimeLeft", i)
end

--> Client -->-----------------------------------
local Freon = require(game.ReplicatedStorage.Modules.Freon)

--> Wait for state (Key: string)
local State = Freon:await("Globals")

--> Print Current State
print(State:get().State.GameTimeLeft)

--> On Update, Print the remaining game time.
State:onUpdate(function(State)
    print(State.GameTimeLeft)
end)
```
