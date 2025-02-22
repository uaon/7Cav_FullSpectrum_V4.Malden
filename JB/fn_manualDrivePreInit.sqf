JB_MDI_RandomSpawnPosition =
{
	[-10000 - random 10000, -10000 - random 10000, 1000 + random 1000]
};

JB_MDI_IsManualDriveVehicle =
{
	if (vehicle player getVariable ["JB_MDI_Active", false]) exitWith { true };

	private _typeFilter = player getVariable ["JB_MDI_TypeFilter", []];

	if (count _typeFilter == 0) exitWith { false };

	([typeOf vehicle player, _typeFilter] call JB_fnc_passesTypeFilter)
};

JB_MDI_ManualDriveCondition =
{
	if (not isNull driver vehicle player) exitWith { false };

	if (player != gunner vehicle player) exitWith { false };

	(call JB_MDI_IsManualDriveVehicle)
};

JB_MDI_ServerMonitor =
{
	_this spawn
	{
		params ["_player", "_driver", "_vehicle"];

		waitUntil { sleep 0.1; _player != gunner _vehicle || { not alive _driver } || { vehicle _driver == _driver } || { not (lifeState _player in ["HEALTHY", "INJURED"]) } };

		deleteVehicle _driver;
		_vehicle engineOn false;
	};
};

JB_MDI_ManualDrive =
{
	[] spawn
	{
		private _player = player;
		private _vehicle = vehicle _player;

		if (not local _vehicle) then
		{
			[[_vehicle, _player], { (_this select 0) setOwner owner (_this select 1) }] remoteExec ["call", 2];
			waitUntil { local _vehicle || not alive _vehicle };
		};

		if (not local _vehicle) exitWith {};

		private _group = createGroup side _player;
		private _driver = _group createUnit ["B_crew_F", call JB_MDI_RandomSpawnPosition, [], 0, "can_collide"];
		_driver assignAsDriver _vehicle;
		_driver moveInDriver _vehicle;

		_driver allowDamage false;

//		[_driver] join group player;
//		deleteGroup _group;

		// Turn off manual drive if any necessary conditions are violated.  Do this on the server in case the player just disconnects.
		[_player, _driver, _vehicle] remoteExec ["JB_MDI_ServerMonitor", 2];
	};
};

JB_MDI_CancelManualDriveCondition =
{
	if (isNull driver vehicle player) exitWith { false };

	if (isPlayer driver vehicle player ) exitWith { false };

	if (player != gunner vehicle player) exitWith { false };

	(call JB_MDI_IsManualDriveVehicle)
};

JB_MDI_CancelManualDrive =
{
	private _driver = driver vehicle player;
	_driver setPos (call JB_MDI_RandomSpawnPosition); // Avoids a blinking moment where the AI is visible while dismounted
	deleteVehicle _driver;
};

JB_MDI_SetupClientVehicle =
{
	params ["_vehicle"];

	_vehicle setVariable ["JB_MDI_Active", true];

	// An action priority of 2 places these actions before actions that change seats
	_vehicle addAction ["Manual drive", JB_MDI_ManualDrive, nil, 2, false, true, "", "[] call JB_MDI_ManualDriveCondition"];
	_vehicle addAction ["Cancel manual drive", JB_MDI_CancelManualDrive, nil, 2, false, true, "", "[] call JB_MDI_CancelManualDriveCondition"];
};

JB_MDI_SetupClientPlayer =
{
	params ["_typeFilter"];

	player setVariable ["JB_MDI_TypeFilter", _typeFilter];

	// An action priority of 2 places these actions before actions that change seats
	player addAction ["Manual drive", JB_MDI_ManualDrive, nil, 2, false, true, "", "[] call JB_MDI_ManualDriveCondition"];
	player addAction ["Cancel manual drive", JB_MDI_CancelManualDrive, nil, 2, false, true, "", "[] call JB_MDI_CancelManualDriveCondition"];
};