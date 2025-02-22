/*
Copyright (c) 2017, John Buehler

Permission is hereby granted, free of charge, to any person obtaining a copy of this software (the "Software"), to deal in the Software, including the rights to use, copy, modify, merge, publish and/or distribute copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

//BUG: If a group is looking for a building to occupy and there aren't any, they won't be told to move to an open area and 'garrison' that.  The initial force handles this, but no other groups do.

if (not isServer && hasInterface) exitWith {};

#include "strongpoint.h"

#define NEAR_ENGAGEMENT_RANGE 200

// The distance from a building at which a group will split into individuals so they can occupy the building
#define OCCUPY_SPLIT_GROUP_DISTANCE 30

#define OUTDOOR_SPACING 5.0
#define OUTDOOR_PROXIMITY_NOFARTHER 10.0

#define TRANSPORT_OPERATION_AIR 0
#define TRANSPORT_OPERATION_SEA 1
#define TRANSPORT_OPERATION_GROUND 2

#ifdef TEST
#define BALANCE_INTERVAL [10,10]
#else
#define BALANCE_INTERVAL [30,60]
#endif

#define MAX_AIR_DROPS 2

SPM_InfantryGarrison_RatingsWest =
[
	["rhsusf_army_ocp_officer", [1, 1]],
	["rhsusf_army_ocp_jfo", [1, 1]],
	["rhsusf_army_ocp_squadleader", [1, 1]],
	["rhsusf_army_ocp_teamleader", [1, 1]],
	["rhsusf_army_ocp_marksman", [1, 1]],
	["rhsusf_army_ocp_machinegunner", [1, 1]],
	["rhsusf_army_ocp_grenadier", [1, 1]],
	["rhsusf_army_ocp_engineer", [1, 1]],
	["rhsusf_army_ocp_medic", [1, 1]],
	["rhsusf_army_ocp_maaws", [1, 1]],
	["rhsusf_army_ocp_rifleman_m4", [1, 1]],
	["rhsusf_army_ocp_rifleman_m4", [1, 1]],
	["rhsusf_army_ocp_sniper_m24sws", [1, 1]],
	["B_T_Soldier_SL_F", [1,1]],
	["B_T_Soldier_TL_F", [1,1]],
	["B_T_Soldier_Repair_F", [1,1]],
	["B_T_soldier_mine_F", [1,1]],
	["B_T_Soldier_Exp_F", [1,1]],
	["B_T_Soldier_Engineer_F", [1,1]],
	["rhsusf_army_ocp_combatcrewman", [1,1]],
	["rhsusf_army_ocp_crewman", [1,1]],
	["rhsusf_army_ocp_officer", [1,1]],
	["rhsusf_army_ocp_driver", [1,1]],
	["rhsusf_army_ocp_arb_riflemanl", [1,1]],
	["rhsusf_army_ocp_arb_squadleader", [1,1]],
	["rhsusf_army_ocp_arb_teamleader", [1,1]],
	["rhsusf_army_ocp_arb_autorifleman", [1,1]],
	["rhsusf_army_ocp_arb_grenadier", [1,1]],
	["rhsusf_army_ocp_arb_rifleman", [1,1]],
	["rhsusf_army_ocp_arb_medic", [1,1]],
	["rhsusf_navy_marpat_wd_medic", [1,1]]
];

SPM_InfantryGarrison_RatingsEast =
[
    ["LOP_US_Infantry_Rifleman", [1, 1]],
    ["LOP_US_Infantry_Corpsman", [1, 1]],
    ["LOP_US_Infantry_Engineer", [1, 1]],
    ["LOP_US_Infantry_MG", [1, 1]],
    ["LOP_US_Infantry_MG_Asst", [1, 1]],
    ["LOP_US_Infantry_MG_2", [1, 1]],
    ["LOP_US_Infantry_AA", [1, 1]],
    ["LOP_US_Infantry_Marksman", [1, 1]],
    ["LOP_US_Infantry_Rifleman_1", [1, 1]],
    ["LOP_US_Infantry_Rifleman_2", [1, 1]],
    ["LOP_US_Infantry_Rifleman_3", [1, 1]],
    ["LOP_US_Infantry_Rifleman_4", [1, 1]],
    ["LOP_US_Infantry_AT", [1, 1]],
    ["LOP_US_Infantry_AT_Asst", [1, 1]],
    ["LOP_US_Infantry_GL", [1, 1]],
    ["LOP_US_Infantry_GL_2", [1, 1]],
    ["LOP_US_Infantry_TL", [1, 1]],
    ["LOP_US_Infantry_SL", [1, 1]],
    ["LOP_US_Infantry_Officer", [1, 1]]
];

SPM_InfantryGarrison_CallupsEast =
[
	[(configfile >> "CfgGroups" >> "East" >> "LOP_US" >> "Infantry" >> "LOP_US_Rifle_squad"), [1, 8, 1.0]]
];

SPM_InfantryGarrison_InitialCallupsEast =
[
	[(configfile >> "CfgGroups" >> "East" >> "LOP_US" >> "Infantry" >> "LOP_US_Patrol_section"), [1, 4, 1.0]],
	[(configfile >> "CfgGroups" >> "East" >> "LOP_US" >> "Infantry" >> "LOP_US_AA_section"), [1, 4, 0.03]],
	[(configfile >> "CfgGroups" >> "East" >> "LOP_US" >> "Infantry" >> "LOP_US_AT_section"), [1, 4, 0.10]],
	[(configfile >> "CfgGroups" >> "East" >> "LOP_US" >> "Infantry" >> "LOP_US_FT_section"), [1, 2, 1.0]]
];

SPM_InfantryGarrison_RatingsEastWater =
[
	["O_diver_TL_F", [1, 1]],
	["O_diver_exp_F", [1, 1]],
	["O_diver_F", [1, 1]]
];

SPM_InfantryGarrison_CallupsEastWater =
[
	[(configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "SpecOps" >> "OI_diverTeam"), [1, 4, 1.0]]
];

SPM_InfantryGarrison_InitialCallupsEastWater =
[
	[(configFile >> "CfgGroups" >> "East" >> "OPF_F" >> "SpecOps" >> "OI_diverTeam"), [1, 4, 1.0]]
];

SPM_InfantryGarrison_RatingsCivilian = "toLower (configName _x) find 'c_man' == 0" configClasses (configFile >> "CfgVehicles");
SPM_InfantryGarrison_CallupsCivilian = SPM_InfantryGarrison_RatingsCivilian apply { [configName _x, [1, 1, 1.0]] };
SPM_InfantryGarrison_RatingsCivilian = SPM_InfantryGarrison_RatingsCivilian apply { [configName _x, [1, 1]] };

SPM_InfantryGarrison_RatingsSyndikat = "toLower (configName _x) find 'LOP_PMC_INFANTRY_' == 0" configClasses (configFile >> "CfgVehicles");
SPM_InfantryGarrison_RatingsSyndikat = SPM_InfantryGarrison_RatingsSyndikat apply { [configName _x, [1, 1]] };

SPM_InfantryGarrison_CallupsSyndikat =
[
	[(configfile >> "CfgGroups" >> "Indep" >> "LOP_PMC" >> "Infantry" >> "LOP_PMC_Rifle_squad"), [1, 8, 1.0]]
];

SPM_InfantryGarrison_InitialCallupsSyndikat =
[

	[(configfile >> "CfgGroups" >> "Indep" >> "LOP_PMC" >> "Infantry" >> "LOP_PMC_Rifle_squad"), [1, 8, 1.0]],
	[(configfile >> "CfgGroups" >> "Indep" >> "LOP_PMC" >> "Infantry" >> "LOP_PMC_Support_section"), [1, 4, 1.0]]
];

SPM_InfantryGarrison_Formations = ["column", "stag column", "wedge", "ech left", "ech right", "vee", "line", "file", "diamond"];

OO_TRACE_DECL(SPM_InfantryGarrison_SpawnGroup) =
{
	params ["_category", "_side", "_descriptor", "_positionInformation"];

	private _group = if (_positionInformation isEqualType objNull)
		then { [_side, [[_positionInformation]] + _descriptor, call SPM_Util_RandomSpawnPosition, 0, true, ["cargo"]] call SPM_fnc_spawnGroup }
		else { [_side, _descriptor, _positionInformation select 0, _positionInformation select 1, false] call SPM_fnc_spawnGroup };

	[_category, _group] call OO_GET(_category,Category,InitializeObject);
	_group setFormation (selectRandom SPM_InfantryGarrison_Formations);

	private _forceUnits = OO_GET(_category,ForceCategory,ForceUnits);
	{
		_forceUnits pushBack ([_x, [_x]] call OO_CREATE(ForceUnit));
	} forEach units _group;

	private _cost = 0;
	{
		_cost = _cost + OO_GET(_x,ForceRating,Rating);
	} forEach ([units _group, OO_GET(_category,ForceCategory,RatingsEast)] call SPM_Force_GetForceRatings);

	[_group, _cost]
};

// Infantry arriving on foot at the edge of the operation
OO_TRACE_DECL(SPM_InfantryGarrison_CallUp) =
{
	params ["_position", "_direction", "_category", "_type"];

	private _reserves = OO_GET(_category,ForceCategory,Reserves);
	if (_reserves == 0) exitWith {};

	private _descriptor = [_type] call SPM_InfantryGarrison_TypeToDescriptor;
	private _spawn = [_category, OO_GET(_category,ForceCategory,SideEast), _descriptor, [_position, _direction]] call SPM_InfantryGarrison_SpawnGroup;

	private _group = _spawn select 0;
	private _cost = _spawn select 1;

	_reserves = _reserves - _cost;
	if (_reserves < 0) exitWith
	{
		{ deleteVehicle _x } forEach units _group;
		deleteGroup _group;
		OO_SET(_category,ForceCategory,Reserves,0);
	};
	OO_SET(_category,ForceCategory,Reserves,_reserves);

	_group setVariable ["SPM_InfantryGarrison_OnGroundTime", diag_tickTime];
	[_category, _group, true, 0.0] call SPM_InfantryGarrison_GarrisonGroup;

	sleep 10; // To space out the spawns
};

// Select a building that can hold at least the specified count of infantry
OO_TRACE_DECL(SPM_InfantryGarrison_AllocateMissionBuilding) =
{
	params ["_category", "_count", "_position"];

	private _building = objNull;
	private _area = OO_GET(_category,ForceCategory,Area);
	private _side = OO_GET(_category,ForceCategory,SideEast);
	private _mission = OO_GETREF(_category,Category,Strongpoint);
	private _missionBuildings = OO_GET(_mission,Mission,Buildings);

	// Get buildings in our area that can accommodate the count of infantry
	private _buildings = [];
	{
		if ([getPos _x] call OO_METHOD(_area,StrongpointArea,PositionInArea) && { count (_x buildingPos -1) >= _count }) then
		{
			_buildings pushBack [_forEachIndex, _x];
		};
	} forEach _missionBuildings; // [[index, building], ...]

	if (count _buildings == 0) exitWith { objNull };

	// Depending on how the housing is selected, either pick completely randomly or be more selective
	private _housingPreference = OO_GET(_category,InfantryGarrisonCategory,HousingPreference);
	if (_housingPreference == -1) then
	{
		_building = selectRandom _buildings;
		_building = _missionBuildings deleteAt (_building select 0);
	}
	else
	{
		_buildings = _buildings apply { [(_x select 1) distanceSqr _position, _x select 0] }; // [[distance, index], ...]
		_buildings sort true;
		private _index = floor random [0, (count _buildings) * _housingPreference, count _buildings];
		_building = _missionBuildings deleteAt (_buildings select _index select 1);
	};

	_building
};

OO_TRACE_DECL(SPM_InfantryGarrison_PlanOccupation) =
{
	params ["_category", "_callups", "_reserves"];

	private _area = OO_GET(_category,ForceCategory,Area);
	private _center = OO_GET(_area,StrongpointArea,Position);

	if (_reserves > 0) then
	{
		private _side = OO_GET(_category,ForceCategory,SideEast);
		private _occupationLimits = OO_GET(_category,InfantryGarrisonCategory,OccupationLimits);

		// Create groups from largest to smallest in cost
		private _descriptors = _callups apply { [(_x select 1 select 0) * (_x select 1 select 1), _x select 1 select 1] }; // [reserve-cost-of-soldiers, number-soldiers]
		_descriptors = _descriptors select { (_x select 1) <= (_occupationLimits select 1) }; // Get rid of any that are too large to fit a building per the occupation limits
		_descriptors sort false;

		private _garrisonBuilding = objNull;
		private _garrisonBuildings = []; // [building, number-open-positions, occupation-limit]

		private _callupCost = 0;
		private _callupSize = 0;

		private _remainingReserves = _reserves;

		private _descriptor = [];
		for "_i" from 0 to (count _descriptors - 1) do
		{
			_descriptor = _descriptors select _i;
			_callupCost = _descriptor select 0;
			_callupSize = _descriptor select 1;

			while { _remainingReserves >= _callupCost } do
			{
				_garrisonBuilding = selectRandom (_garrisonBuildings select { _callupSize <= _x select 1 });
				if (isNil "_garrisonBuilding") then
				{
					_garrisonBuilding = [_category, _callupSize, _center] call SPM_InfantryGarrison_AllocateMissionBuilding;
					if (isNull _garrisonBuilding) then
					{
						_garrisonBuilding = [];
					}
					else
					{
						private _occupationLimit = (_occupationLimits select 0) + random ((_occupationLimits select 1) - (_occupationLimits select 0));
						_occupationLimit = _occupationLimit max _callupSize;

						_garrisonBuilding = [_garrisonBuilding, (count (_garrisonBuilding buildingPos -1)) min _occupationLimit, _occupationLimit];
						_garrisonBuildings pushBack _garrisonBuilding
					};
				};

				if (count _garrisonBuilding == 0) exitWith
				{
					// Skip over additional descriptors that have the same cost and unit size
					while { _i+1 < count _descriptors && { (_descriptors select (_i+1) select 0) == (_descriptor select 0) && (_descriptors select (_i+1) select 1) == (_descriptor select 1) } } do
					{
						_i = _i + 1;
					};
				};

				_garrisonBuilding set [1, (_garrisonBuilding select 1) - _callupSize];
				_remainingReserves = _remainingReserves - _callupCost;
			};
		};

		_garrisonBuildings = _garrisonBuildings apply { [_x select 0, _x select 2] };
		OO_SET(_category,InfantryGarrisonCategory,GarrisonBuildings,_garrisonBuildings);

		private _isUrbanEnvironment = (1.0 - (_remainingReserves / _reserves)) > OO_GET(_category,InfantryGarrisonCategory,UrbanThreshhold);
		OO_SET(_category,InfantryGarrisonCategory,IsUrbanEnvironment,_isUrbanEnvironment);
	};

	// Identify outdoor positions that can be 'garrisoned'
	private _innerRadius = OO_GET(_area,StrongpointArea,InnerRadius);
	private _outerRadius = OO_GET(_area,StrongpointArea,OuterRadius);

	private _primaryPositions = [_center, _innerRadius, _outerRadius, (_outerRadius -_innerRadius) * 0.2] call SPM_Util_SampleAreaGrid;
	[_primaryPositions, ["#GdtWater"]] call SPM_Util_ExcludeSamplesBySurfaceType;
	[_primaryPositions, OUTDOOR_SPACING, ["BUILDING", "HOUSE", "ROCK"]] call SPM_Util_ExcludeSamplesByProximity;
	private _secondaryPositions = +_primaryPositions;
	[_primaryPositions, OUTDOOR_PROXIMITY_NOFARTHER, ["BUILDING", "HOUSE", "ROCK"], _primaryPositions] call SPM_Util_ExcludeSamplesByProximity;

	_secondaryPositions = _secondaryPositions - _primaryPositions;

	_primaryPositions = _primaryPositions apply { [_x distanceSqr _center, _x] };
	_primaryPositions sort true;

	_secondaryPositions = _secondaryPositions apply { [_x distanceSqr _center, _x] };
	_secondaryPositions sort true;

	private _outdoorPositions = _primaryPositions + _secondaryPositions;
	_outdoorPositions = _outdoorPositions apply { _x select 1 };

	OO_SET(_category,InfantryGarrisonCategory,OutdoorPositions,_outdoorPositions);
};

// Find space in one of the garrison buildings for these soldiers
OO_TRACE_DECL(SPM_InfantryGarrison_AllocateGarrisonBuilding) =
{
	params ["_category", "_soldiers", "_buildingProximity"];

	private _numberSoldiers = count _soldiers;

	private _occupationLimits = OO_GET(_category,InfantryGarrisonCategory,OccupationLimits);
	private _garrisonBuildings = OO_GET(_category,InfantryGarrisonCategory,GarrisonBuildings);

	private _building = objNull;
	private _buildings = [];
	private _understrengthBuildings = [];
	private _counts = [];
	private _remainingSpace = 0;
	{
		_counts = [_x select 0] call SPM_Occupy_OccupationCounts;
		_remainingSpace = ((_counts select 0) min (_x select 1)) - (_counts select 1);
		if (_remainingSpace >= _numberSoldiers) then
		{
			if (_counts select 1 > 0 && _counts select 1 < _occupationLimits select 0) then { _understrengthBuildings pushBack (_x select 0) } else { _buildings pushBack (_x select 0) };
		};
	} forEach _garrisonBuildings;

	if (count _understrengthBuildings > 0) then { _buildings = _understrengthBuildings };

	if (count _buildings == 0) exitWith { objNull };

	// Depending on proximity setting, either pick completely randomly or be more selective
	if (_buildingProximity == -1) then
	{
		_building = selectRandom _buildings;
	}
	else
	{
		private _soldierPosition = getPos (_soldiers select 0);

		_buildings = _buildings apply { [_x distance _soldierPosition, _x] }; // [[distance-to-building, building], ...]
		_buildings sort true;

		private _index = floor random [0, (count _buildings) * _buildingProximity, count _buildings];
		_building = _buildings select _index select 1;
	};

	{ [_building, _x] call SPM_Occupy_AllocateBuildingEntry } forEach _soldiers;

	_building
};

// Move to the nearest suitable building as a group.  Upon arrival, if that building is still suitable, occupy it.  If not suitable,
// look for another and move to it as a group.  Repeat as needed.  If no suitable buildings are left, the group occupies an outdoor position.
OO_TRACE_DECL(SPM_InfantryGarrison_GarrisonGroup) =
{
	params ["_category", "_group", "_priority", "_buildingProximity"];

	OO_GET(_category,InfantryGarrisonCategory,HousedUnits) append units _group;

	private _building = [_category, units _group, _buildingProximity] call SPM_InfantryGarrison_AllocateGarrisonBuilding;

	if (not isNull _building) then
	{
		// If the building the group is supposed to enter is close enough, enter it.
		if (_building distance leader _group < OCCUPY_SPLIT_GROUP_DISTANCE ) then
		{
			[_group, _building, "simultaneous"] call SPM_fnc_occupyEnterBuilding;
		}
		else
		{
			private _leader = leader _group;
			private _destination = getPos _building;

			// Otherwise, try to reach a point close to the building as a group, then enter as individuals.

			// Start with the nearest building exit
			private _exits = ([_building] call SPM_Occupy_GetBuildingExits) apply { [_x distance _leader, _x] };
			_exits sort true;
			_destination = _exits select 0 select 1;

			// But because building exits are not reliable, we have to search for a clear spot nearby.  If nothing
			// works, we'll be left with the building exit.

			// Try nearby roads (cheap), then any clear spot (expensive)
			private _roads = _destination nearRoads 30;
			if (count _roads > 0) then
			{
				_roads = _roads apply { [(_leader distance2D _x) + (_destination distance2D _x), _x] };
				_roads sort true;
				_destination = getPos (_roads select 0 select 1);
			}
			else
			{
				private _positions = [_destination, 10, 25, 7] call SPM_Util_SampleAreaGrid;
				[_positions, ["#GdtWater"]] call SPM_Util_ExcludeSamplesBySurfaceType;
				[_positions, 2, ["BUILDING", "HOUSE", "ROCK", "HIDE", "TREE", "WALL"]] call SPM_Util_ExcludeSamplesByProximity;
				if (count _positions > 0) then
				{
					_destination = _positions select 0;
				};
			};

			private _onArrival =
			{
				params ["_leader", "_units", "_building"];
				[group _leader] call SPM_InfantryGarrison_GroupEngage;
				[group _leader, _building, "simultaneous"] call SPM_fnc_occupyEnterBuilding;
			};

			if (_priority) then { [_group, 30] call SPM_InfantryGarrison_GroupAdvance };

			private _waypoint = [_group, _destination] call SPM_AddPatrolWaypoint;
			[_waypoint, _onArrival, _building] call SPM_AddPatrolWaypointStatements;
		};
	}
	else
	{
		private _outdoorPositions = OO_GET(_category,InfantryGarrisonCategory,OutdoorPositions);
		if (count _outdoorPositions == 0) then { private _area = OO_GET(_category,ForceCategory,Area); _outdoorPositions = [OO_GET(_area,StrongpointArea,Position)] };

		if (_priority) then { [_group, 30] call SPM_InfantryGarrison_GroupAdvance };

		private _position = _outdoorPositions deleteAt 0;
		private _waypoint = _group addWaypoint [_position, 0];
		_waypoint setWaypointType "move";
	};
};

OO_TRACE_DECL(SPM_InfantryGarrison_GarrisonGroupInstant) =
{
	params ["_category", "_group", "_buildingProximity"];

	OO_GET(_category,InfantryGarrisonCategory,HousedUnits) append units _group;

	private _building = [_category, units _group, _buildingProximity] call SPM_InfantryGarrison_AllocateGarrisonBuilding;

	if (isNull _building && not OO_GET(_category,InfantryGarrisonCategory,HouseOutdoors)) exitWith { false };

	if (not isNull _building) then
	{
		[_group, _building, "instant"] call SPM_fnc_occupyEnterBuilding;
	}
	else
	{
		private _outdoorPositions = OO_GET(_category,InfantryGarrisonCategory,OutdoorPositions);
		if (count _outdoorPositions == 0) then { private _area = OO_GET(_category,ForceCategory,Area); _outdoorPositions = [OO_GET(_area,StrongpointArea,Position)] };

		private _position = _outdoorPositions deleteAt 0;
		private _unitPosition = [];
		{
			_unitPosition = _position vectorAdd ([-OUTDOOR_SPACING + (random OUTDOOR_SPACING * 2), -OUTDOOR_SPACING + (random OUTDOOR_SPACING * 2), 0]);
			[_x, _unitPosition] call SPM_Util_PlaceVehicleOnSurface;
			doStop _x; // To prevent them from walking into their formation
		} forEach units _group;
	};

	true
};

OO_TRACE_DECL(SPM_InfantryGarrison_TypeToDescriptor) =
{
	params ["_type"];

	private _descriptor = [];
	switch (typeName _type) do
	{
		case "CONFIG": { _descriptor = ([_type] call SPM_fnc_groupFromConfig) select 1 };
		case "STRING": { _descriptor = ([[_type]] call SPM_fnc_groupFromClasses) select 1 };
		case "ARRAY": { _descriptor = ([_type] call SPM_fnc_groupFromClasses) select 1 };
		default { diag_log format ["SPM_InfantryGarrison_CreateInitialForce: unhandled callup '%1'", _type] };
	};

	_descriptor
};

OO_TRACE_DECL(SPM_InfantryGarrison_CreateInitialForce) =
{
	params ["_category"];

	private _occupationLimits = OO_GET(_category,InfantryGarrisonCategory,OccupationLimits);
	private _initialReserves = OO_GET(_category,InfantryGarrisonCategory,InitialReserves) min OO_GET(_category,ForceCategory,Reserves);
	private _difficulty = OO_GET(_category,ForceCategory,DifficultyLevel);
	_initialReserves = _initialReserves * _difficulty;

	_initialReserves = _initialReserves min OO_GET(_category,ForceCategory,Reserves);

	if (_initialReserves > 0) then
	{
		private _side = OO_GET(_category,ForceCategory,SideEast);
		private _callups = OO_GET(_category,InfantryGarrisonCategory,InitialCallupsEast) apply { [_x select 1 select 1, _x ] }; // [number-soldiers, callup-structure]
		_callups = _callups select { _x select 0 <= (_occupationLimits select 1) };
		_callups sort false;
		private _weights = _callups apply { _x select 1 select 1 select 2 };

		private _area = OO_GET(_category,ForceCategory,Area);
		private _center = OO_GET(_area,StrongpointArea,Position);

		private _consumedReserves = 0;
		private _units = [];
		private _occupying = true;
		while { _occupying } do
		{
			while { count _callups > 0 && { _initialReserves < _callups select 0 select 0 } } do { _callups deleteAt 0; _weights deleteAt 0 };

			if (count _callups == 0) exitWith {};

			private _callup = _callups selectRandomWeighted _weights;
			private _descriptor = [_callup select 1 select 0] call SPM_InfantryGarrison_TypeToDescriptor;

			private _spawn = [_category, _side, _descriptor, [_center, 0]] call SPM_InfantryGarrison_SpawnGroup;
			private _group = _spawn select 0;
			private _cost = _spawn select 1;

			if ([_category, _group, -1] call SPM_InfantryGarrison_GarrisonGroupInstant) then
			{
				_units append units _group;
				_consumedReserves = _consumedReserves + _cost;
				_initialReserves = _initialReserves - _cost;
			}
			else
			{
				_occupying = false;
				{ deleteVehicle _x } forEach units _group;
				deleteGroup _group;
			};
		};

		private _reserves = OO_GET(_category,ForceCategory,Reserves) - _consumedReserves;
		OO_SET(_category,ForceCategory,Reserves,_reserves);
	};

//	OO_SET(_category,InfantryGarrisonCategory,InitialReserves,0); // Don't clear this because other categories use this value
	OO_SET(_category,InfantryGarrisonCategory,InitialForceCreated,true);
};

// Have the group advance aggressively until one of their number is killed by enemy fire or there is enemy gunfire heard within 10m
SPM_InfantryGarrison_GroupAdvance =
{
	params ["_group", ["_engageDistance", -1, [0]]];

	private _soldier = objNull;
	private _killedHandler = -1;
	private _firedNearHandler = -1;

	_group setSpeedMode "full";
	_group setBehaviour "aware";
	{
		_soldier = _x;

		{ _soldier disableAI _x } foreach ["cover", "suppression", "target", "autotarget", "autocombat"];
		if (stance _soldier in ["crouch", "prone"]) then { _soldier setUnitPos "up" }; //TODO: We just want him to get up, not stay up forever

		_killedHandler = _soldier addEventHandler ["Killed",
			{
				params ["_unit", "_killer", "_instigator"];

				if (not isNull _instigator && { side group _instigator != side group _unit }) then { [group _unit] call SPM_InfantryGarrison_GroupEngage };
			}];

		_firedNearHandler = -1;
		if (_engageDistance > 0) then
		{
			_firedNearHandler = _soldier addEventHandler ["FiredNear",
				{
					params ["_unit", "_firer", "_distance", "_weapon", "_muzzle", "_mode", "_ammo", "_gunner"];

					if (not isNull _firer && { side group _firer != side group _unit } && { _distance < (_unit getVariable "SPM_InfantryGarrison_GroupAdvance") select 2 }) then { [group _unit] call SPM_InfantryGarrison_GroupEngage };
				}];
		};

		_soldier setVariable ["SPM_InfantryGarrison_GroupAdvance", [_killedHandler, _firedNearHandler, _engageDistance]];
	} foreach units _group;

	[leader _group, "GroupAdvance", "Advance"] call TRACE_SetObjectString;
};

OO_TRACE_DECL(SPM_InfantryGarrison_GroupEngage) =
{
	params ["_group"];

	private _soldier = objNull;
	private _handlers = [];

	{
		_soldier = _x;
		{ _soldier enableAI _x } foreach ["cover", "suppression", "target", "autotarget", "autocombat"];
		_handlers = _soldier getVariable ["SPM_InfantryGarrison_GroupAdvance", [-1,-1,-1]];
		_soldier removeEventHandler ["Killed", _handlers select 0];
		if ((_handlers select 1) != -1) then { _soldier removeEventHandler ["FiredNear", _handlers select 1] };
	} foreach units _group;

	[leader _group, "GroupAdvance", nil] call TRACE_SetObjectString;
};

OO_TRACE_DECL(SPM_InfantryGarrison_TransportOnLoad) =
{
	params ["_request"];

	OO_GET(_request,TransportRequest,ClientData) params ["_category", "_type"];
	_category = OO_INSTANCE(_category);

	private _reserves = OO_GET(_category,ForceCategory,Reserves);
	if (_reserves <= 1e-4) exitWith { false };

	private _side = OO_GET(_category,ForceCategory,SideEast);

	private _descriptor = [_type] call SPM_InfantryGarrison_TypeToDescriptor;

	private _forceUnit = OO_GET(_request,TransportRequest,ForceUnit);
	private _transportVehicle = OO_GET(_forceUnit,ForceUnit,Vehicle);

	//TODO: This is policy that matches up with SPM_MoveIntoVehicleCargo.  It should be moved over to the SPM_Spawn stuff and called from here.  It's looking for cargo seats plus "turrets" that allow personal weapon use
	private _cargoSeatCount = count (((fullCrew [_transportVehicle, "cargo", true]) select { isNull (_x select 0) }) + ((fullCrew [_transportVehicle, "turret", true]) select { isNull (_x select 0) && (_x select 4) }));
	if (_cargoSeatCount < count _descriptor) then
	{
		_descriptor = _descriptor select [0, _cargoSeatCount];
	};

	private _spawn = [_category, _side, _descriptor, _transportVehicle] call SPM_InfantryGarrison_SpawnGroup;
	private _infantryGroup = _spawn select 0;

	private _reserves = OO_GET(_category,ForceCategory,Reserves);
	_reserves = _reserves - (_spawn select 1);
	OO_SET(_category,ForceCategory,Reserves,_reserves);

	true
};

OO_TRACE_DECL(SPM_InfantryGarrison_Dismount) =
{
	params ["_units"];

	if (count _units == 0) exitWith {};

	private _firedSmoke = false;
	{
		private _unit = _x;

		// If we haven't fired smoke and our guys are getting hit and there's no other covering smoke, fire smoke
		if (not _firedSmoke && { { damage _x > 0.25 } count _units > 0 } && { count (_unit nearObjects ["SmokeShellVehicle", 50]) == 0 }) then
		{
			{
				if ("SmokeLauncher" in (vehicle _unit weaponsTurret _x)) exitWith { [vehicle _unit, _x, "SmokeLauncher"] call SPM_Util_FireTurretWeapon };
			} forEach allTurrets vehicle _unit;
			_firedSmoke = true;
		};

		unassignVehicle _unit;
		[_unit] allowGetIn false;
		[_unit] orderGetIn false;
	} forEach _units;
};

OO_TRACE_DECL(SPM_InfantryGarrison_TransportOnUpdate) =
{
	params ["_request"];

	private _state = OO_GET(_request,TransportRequest,State);

	if (_state != "to-destination") exitWith {};

	private _transportForceUnit = OO_GET(_request,TransportRequest,ForceUnit);
	private _transportVehicle = OO_GET(_transportForceUnit,ForceUnit,Vehicle);
	private _transportCommander = effectiveCommander _transportVehicle;
	private _transportPosition = getPos _transportCommander;

	private _operation = OO_GETREF(_request,TransportRequest,Operation);
	private _area = OO_GET(_operation,TransportOperation,Area);
	private _areaRadius = OO_GET(_area,StrongpointArea,OuterRadius);

	private _westCount = { lifeState _x in ["HEALTHY", "INJURED"] && vehicle _x == _x } count (_transportCommander targets [true, NEAR_ENGAGEMENT_RANGE]);

	// If encountering noteworthy resistance
	if (_westCount >= 4) then
	{
		private _eastSide = OO_GET(_category,ForceCategory,SideEast);
		private _eastCount = { lifeState _x in ["HEALTHY", "INJURED"] && vehicle _x == _x && side _x == _eastSide } count (_transportCommander nearEntities ["Man", NEAR_ENGAGEMENT_RANGE]);

		// If the resistance is greater than friendly forces
		if (_westCount > _eastCount) then
		{
			// Tell the transport to unload us in cover
			if (not ([50, 100] call OO_METHOD(_request,TransportRequestGround,CommandMoveToCover))) then
			{
				// Or move to a clear area
				if (not ([50, 100] call OO_METHOD(_request,TransportRequestGround,CommandMoveToClearing))) then
				{
					// Or just stop where we are
					[] call OO_METHOD(_request,TransportRequestGround,CommandStop);
				};
			};
		};
	};
};

OO_TRACE_DECL(SPM_InfantryGarrison_TransportOnArriveGround) =
{
	params ["_request"];

	// We don't want to hear anything more from the transport guys
	OO_SET(_request,TransportRequest,OnUpdate,{});
	OO_SET(_request,TransportRequest,OnArrive,{});
	OO_SET(_request,TransportRequest,OnSalvage,{});
	OO_SET(_request,TransportRequest,OnSurrender,{});

	private _clientData = OO_GET(_request,TransportRequest,ClientData);
	private _category = OO_INSTANCE(_clientData select 0);

	private _forceUnit = OO_GET(_request,TransportRequest,ForceUnit);

	private _groups = [];
	{
		_groups pushBackUnique group _x;
	} forEach assignedCargo OO_GET(_forceUnit,ForceUnit,Vehicle);

	private _units = [];
	{
		_units append units _x;
		_x setVariable ["SPM_InfantryGarrison_OnGroundTime", diag_tickTime]; //BUG: If the garrison building chosen by GarrisonGroup is close by, this will be immediately lost when GarrisonGroup splits up the group to enter the building
		[_category, _x, true, 0.0] call SPM_InfantryGarrison_GarrisonGroup;
	} forEach _groups;

	[_request, _units] spawn
	{
		params ["_request", "_units"];

		[] call OO_METHOD(_request,TransportRequestGround,CommandStop);
		[_units] call SPM_InfantryGarrison_Dismount;
		sleep (8 + random 3); // Give troops a chance to move away
		[] call OO_METHOD(_request,TransportRequestGround,CommandRetire);
	};

	0
};

OO_TRACE_DECL(SPM_InfantryGarrison_TransportOnArriveAir) =
{
	params ["_request"];

	// We don't want to hear anything more from the transport guys
	OO_SET(_request,TransportRequest,OnUpdate,{});
	OO_SET(_request,TransportRequest,OnArrive,{});
	OO_SET(_request,TransportRequest,OnSalvage,{});
	OO_SET(_request,TransportRequest,OnSurrender,{});

	private _clientData = OO_GET(_request,TransportRequest,ClientData);
	private _category = OO_INSTANCE(_clientData select 0);

	private _forceUnit = OO_GET(_request,TransportRequest,ForceUnit);

	[_category, OO_GET(_forceUnit,ForceUnit,Vehicle)] spawn
	{
		params ["_category", "_aircraft"];

		scriptName "spawnSPM_InfantryGarrison_TransportOnArriveAir";

		private _units = (fullCrew [_aircraft, "cargo"]) select { alive (_x select 0) };
		_units append ((fullCrew [_aircraft, "turret"]) select { alive (_x select 0) && (_x select 4) }); // Turrets that permit personal weapons
		_units = _units apply { _x select 0 };

		{
			[_x, true] call JB_fnc_halo;
			sleep 0.5;
		} forEach _units;

		// Wait until all livng members of the group are out of parachutes.
		waitUntil { sleep 0.5; ({ alive _x && { vehicle _x != _x } } count _units) == 0 };

		private _groups = []; { _groups pushBackUnique group _x } forEach (_units select { alive _x });
		{
			_x setVariable ["SPM_InfantryGarrison_OnGroundTime", diag_tickTime];
			[_category, _x, true, 0.0] call SPM_InfantryGarrison_GarrisonGroup;
		} forEach _groups;
	};

	0
};

OO_TRACE_DECL(SPM_InfantryGarrison_TransportOnSurrenderGround) =
{
	params ["_request"];

	// We don't want to hear anything more from the transport guys
	OO_SET(_request,TransportRequest,OnUpdate,{});
	OO_SET(_request,TransportRequest,OnArrive,{});
	OO_SET(_request,TransportRequest,OnSalvage,{});
	OO_SET(_request,TransportRequest,OnSurrender,{});
};

OO_TRACE_DECL(SPM_InfantryGarrison_TransportOnSurrenderAir) =
{
	params ["_request"];

	// We don't want to hear anything more from the transport guys
	OO_SET(_request,TransportRequest,OnUpdate,{});
	OO_SET(_request,TransportRequest,OnArrive,{});
	OO_SET(_request,TransportRequest,OnSalvage,{});
	OO_SET(_request,TransportRequest,OnSurrender,{});

	private _forceUnit = OO_GET(_request,TransportRequest,ForceUnit);
	if (count _forceUnit > 0) then
	{
		private _aircraft = OO_GET(_forceUnit,ForceUnit,Vehicle);

		private _unloadData = _aircraft getVariable "SPM_InfantryGarrison_Unload";
		private _infantryGroup = _unloadData select 0;

		// If unit is off the ground (waiting to parachute), delete the unit
		{
			if ((getPos _x) select 2 > 1 && vehicle _x == _x) then
			{
				deleteVehicle _x;
			};
		} forEach units _infantryGroup;

		if (count units _infantryGroup == 0) then { deleteGroup _infantryGroup; };
	};
};

OO_TRACE_DECL(SPM_InfantryGarrison_TransportOnSalvage) =
{
	params ["_request"];

	private _clientData = OO_GET(_request,TransportRequest,ClientData);
	private _category = OO_INSTANCE(_clientData select 0);

	if (isNil "_category") exitWith {}; // If a strongpoint is being deleted, the supporting category may be deleted out from under us

	private _transportForceUnit = OO_GET(_request,TransportRequest,ForceUnit);
	private _groups = [];
	{
		_groups pushBackUnique group _x;
	} forEach assignedCargo OO_GET(_transportForceUnit,ForceUnit,Vehicle);

	{
		{
			[_category, _x] call SPM_Force_SalvageForceUnit;
		} forEach units _x;
		deleteGroup _x;
	} forEach _groups;
};

OO_TRACE_DECL(SPM_InfantryGarrison_FindOperationUnloadPositions) =
{
	params ["_category", "_origin"];

	private _area = OO_GET(_category,ForceCategory,Area);
	private _center = OO_GET(_area,StrongpointArea,Position);
	private _radius = OO_GET(_area,StrongpointArea,OuterRadius) + OO_GET(_category,InfantryGarrisonCategory,ActivityBorder);

	private _positions = [];
	private _searchRadius = 0;
	while { count _positions == 0 && _searchRadius < 200 } do
	{
		_positions = [_center, _radius + _searchRadius, 2, "degrees", (_center getDir _origin) - 30, 30] call SPM_Util_SampleAreaPerimeter;
		[_positions, ["#GdtWater"]] call SPM_Util_ExcludeSamplesBySurfaceType;
		[_positions, 10.0, ["WALL", "BUILDING", "HOUSE", "ROCK", "ROAD"]] call SPM_Util_ExcludeSamplesByProximity;

		_searchRadius = _searchRadius + 20;
	};

	if (count _positions > 0) exitWith { _positions };

	// Wherever a straight line from the origin to the center of the area intersects the outer edge of the area plus a walking distance
	_center vectorAdd ((_center vectorFromTo _origin) vectorMultiply _radius)
};

OO_TRACE_DECL(SPM_InfantryGarrison_FindOperationDropPosition) =
{
	params ["_origin", "_area"];

	private _center = OO_GET(_area,StrongpointArea,Position);
	private _radius = OO_GET(_area,StrongpointArea,OuterRadius);

	private _normal = _center vectorFromTo _origin;
	private _dropPosition = _center vectorAdd (_normal vectorMultiply _radius);
	if (surfaceIsWater _dropPosition) then
	{
		private _positions = [_center, _radius, 50, "samples"] call SPM_Util_SampleAreaPerimeter;
		[_positions, ["#GdtWater"]] call SPM_Util_ExcludeSamplesBySurfaceType;

		if (count _positions == 0) exitWith { _dropPosition = _center };

		_positions = _positions apply { [_x distance _center, _x] };
		_positions sort true;
		_dropPosition = _positions select 0 select 1;
	};

	_dropPosition
};

OO_TRACE_DECL(SPM_InfantryGarrison_GetBeachPositions) =
{
	params ["_category", "_number"];

	private _area = OO_GET(_category,ForceCategory,Area);

	private _positions = [OO_GET(_area,StrongpointArea,Position), 0, OO_GET(_area,StrongpointArea,OuterRadius) + OO_GET(_category,InfantryGarrisonCategory,ActivityBorder), 20.0] call SPM_Util_SampleAreaGrid;

	private _beachPositions = [];
	[_positions, -1.5, 0.5, _beachPositions] call SPM_Util_ExcludeSamplesByHeightASL;
	[_beachPositions, ["#GdtBeach"], _beachPositions] call SPM_Util_ExcludeSamplesBySurfaceType;
	[_beachPositions, 20, 90] call SPM_Util_ExcludeSamplesBySurfaceIncline;
	[_beachPositions, 10.0, ["BUILDING", "HIDE", "ROCK", "WALL"]] call SPM_Util_ExcludeSamplesByProximity;  // piers are buildings, rocky jetties are hides

	if (count _beachPositions <= _number) exitWith { _beachPositions };

	_beachPositions = _beachPositions apply { [_x distance OO_GET(_area,StrongpointArea,Position), _x] };
	_beachPositions sort true;

	(_beachPositions select [0, _number]) apply { _x select 1 }
};

OO_TRACE_DECL(SPM_InfantryGarrison_Balance) =
{
	params ["_category"];

	// Remove dead or deleted infantry units from unit list
	[OO_GET(_category,ForceCategory,ForceUnits), { private _unit = OO_GET(_this select 2,ForceUnit,Vehicle); not alive _unit }] call SPM_Util_DeleteArrayElements;

	// Don't rebalance if transport callups are under way
	private _pendingOperations = OO_GET(_category,InfantryGarrisonCategory,TransportOperations) select { { OO_GET(_x,TransportRequest,State) in ["create", "pending"] } count OO_GET(_x,TransportOperation,Requests) > 0 };
	OO_SET(_category,InfantryGarrisonCategory,TransportOperations,_pendingOperations);
	if (count _pendingOperations > 0) exitWith {};

	// Get the force levels of east and west
	private _westForce = [OO_GET(_category,ForceCategory,RangeWest)] call OO_METHOD(_category,ForceCategory,GetForceLevelsWest);
	private _eastForce = [-1] call OO_METHOD(_category,ForceCategory,GetForceLevelsEast);

	// Find out what we need to do to balance things out

	private _changes = [_category, _westForce, _eastForce] call SPM_Force_Rebalance;

	private _callups = CHANGES(_changes,callup);
	private _reserves = CHANGES(_changes,reserves);

	//TODO: Retire

	//TODO: Reinstate

	// Callups

	if (count _callups > 0) then
	{
		private _strongpoint = OO_GETREF(_category,Category,Strongpoint);
		private _area = OO_GET(_category,ForceCategory,Area);
		private _approachDirection = OO_GET(_category,ForceCategory,CallupDirection);

		//TODO: Arrival by foot should always be able to work, even if we have to hunt around for dry land in the garrison area
		private _transport = OO_GET(_category,InfantryGarrisonCategory,Transport);
		if (OO_ISNULL(_transport)) then
		{
			private _spawnManager = OO_GET(_strongpoint,Strongpoint,SpawnManager);
			private _groundSpawnpoint = [OO_GET(_area,StrongpointArea,Position), OO_GET(_area,StrongpointArea,OuterRadius) + OO_GET(_category,InfantryGarrisonCategory,ActivityBorder), OO_GET(_category,ForceCategory,SideWest), _approachDirection select 0, _approachDirection select 1] call SPM_Util_GetGroundSpawnpoint;
			{
				[_groundSpawnpoint select 0, _groundSpawnpoint select 1, SPM_InfantryGarrison_CallUp, [_category, _x select 0]] call OO_METHOD(_spawnManager,SpawnManager,ScheduleSpawn);
			} forEach _callups;
		}
		else
		{
			private _seaSpawnpoint = [[],0];
			if (count OO_GET(_transport,TransportCategory,SeaTransports) > 0 && OO_GET(_category,InfantryGarrisonCategory,TransportBySea) > 0) then
			{
				_seaSpawnpoint = [OO_GET(_strongpoint,Strongpoint,Position), OO_GET(_strongpoint,Strongpoint,ActivityRadius), OO_GET(_category,ForceCategory,SideWest), _approachDirection select 0, _approachDirection select 1] call SPM_Util_GetSeaSpawnpoint;
			};

			private _groundSpawnpoint = [[],0];
			if (count OO_GET(_transport,TransportCategory,GroundTransports) > 0 && OO_GET(_category,InfantryGarrisonCategory,TransportByGround) > 0) then
			{
				_groundSpawnpoint = [OO_GET(_strongpoint,Strongpoint,Position), OO_GET(_strongpoint,Strongpoint,ActivityRadius), OO_GET(_area,StrongpointArea,Position), OO_GET(_area,StrongpointArea,OuterRadius) max 100, OO_GET(_category,ForceCategory,SideWest), _approachDirection select 0, _approachDirection select 1] call SPM_Util_GetRoadSpawnpoint;
				if (count (_groundSpawnpoint select 0) == 0) then { _groundSpawnpoint = [OO_GET(_strongpoint,Strongpoint,Position), OO_GET(_strongpoint,Strongpoint,ActivityRadius), OO_GET(_category,ForceCategory,SideWest), _approachDirection select 0, _approachDirection select 1] call SPM_Util_GetGroundSpawnpoint };
			};

			private _airSpawnpoint = [[],0];
			if (count OO_GET(_transport,TransportCategory,AirTransports) > 0 && OO_GET(_category,InfantryGarrisonCategory,TransportByAir) > 0) then
			{
				_airSpawnpoint = [OO_GET(_strongpoint,Strongpoint,Position), OO_GET(_strongpoint,Strongpoint,ActivityRadius), 500, 100, _approachDirection select 0, _approachDirection select 1] call SPM_Util_GetAirSpawnpoint;
			};

			private _weights = [0.0, 0.0, 0.0];
			if (count (_seaSpawnpoint select 0) > 0) then { _weights set [0, OO_GET(_category,InfantryGarrisonCategory,TransportBySea)] };
			if (count (_groundSpawnpoint select 0) > 0) then { _weights set [1, OO_GET(_category,InfantryGarrisonCategory,TransportByGround)] };
			if (count (_airSpawnpoint select 0) > 0) then { _weights set [2, OO_GET(_category,InfantryGarrisonCategory,TransportByAir)] };

			_weights set [1, (1.0 - (_weights select 0)) * (_weights select 1)];
			_weights set [2, (1.0 - (_weights select 1)) * (_weights select 2)];

			private _seaOperation = OO_NULL;
			private _groundOperation = OO_NULL;
			private _airOperation = OO_NULL;

			private _seaDestinations = nil; // Don't recycle sea destination points (beach positions) within a callup set
			private _groundDestinations = [];
			private _airDestination = [];

			private _airDropCount = 0;

			private _operation = OO_NULL;
			private _request = OO_NULL;
			private _callup = [];

			while { count _callups > 0 && _weights findIf { _x != 0.0 } >= 0 } do
			{
				_callup = _callups select 0;
				_request = OO_NULL;

				switch (["sea", "ground", "air"] selectRandomWeighted _weights) do
				{
					case "sea":
					{
						if (isNil "_seaDestinations") then { _seaDestinations = [_category, count _callups] call SPM_InfantryGarrison_GetBeachPositions };
						if (count _seaDestinations == 0) then
						{
							_weights set [0, 0.0]; // Don't try another sea transport in this callup set
						}
						else
						{
							if (OO_ISNULL(_seaOperation)) then
							{
								_seaOperation = [_area, _seaSpawnpoint] call OO_CREATE(TransportOperation);
								private _callups = OO_GET(_transport,TransportCategory,SeaTransports);
								OO_SET(_seaOperation,TransportOperation,VehicleCallups,_callups);
							};

							_destination = floor random count _seaDestinations;
							_destination = _seaDestinations deleteAt _destination;

							_request = [_callup select 1 select 1, _destination] call OO_CREATE(TransportRequestGround);
							OO_SET(_request,TransportRequest,OnArrive,SPM_InfantryGarrison_TransportOnArriveGround);
							OO_SET(_request,TransportRequest,OnSurrender,SPM_InfantryGarrison_TransportOnSurrenderGround);

							_operation = _seaOperation;
						};
					};

					case "ground":
					{
						if (OO_ISNULL(_groundOperation)) then
						{
							_groundOperation = [_area, _groundSpawnpoint] call OO_CREATE(TransportOperation);
							private _callups = OO_GET(_transport,TransportCategory,GroundTransports);
							OO_SET(_groundOperation,TransportOperation,VehicleCallups,_callups);
						};

						if (count _groundDestinations == 0) then { _groundDestinations = [_category, _groundSpawnpoint select 0] call SPM_InfantryGarrison_FindOperationUnloadPositions };
						_destination = floor random count _groundDestinations;
						_destination = _groundDestinations deleteAt _destination;

						_request = [_callup select 1 select 1, _destination] call OO_CREATE(TransportRequestGround);
						OO_SET(_request,TransportRequest,OnArrive,SPM_InfantryGarrison_TransportOnArriveGround);
						OO_SET(_request,TransportRequest,OnSurrender,SPM_InfantryGarrison_TransportOnSurrenderGround);

						_operation = _groundOperation;
					};

					case "air":
					{
						if (OO_ISNULL(_airOperation)) then
						{
							_airOperation = [_area, _airSpawnpoint] call OO_CREATE(TransportOperation);
							private _callups = OO_GET(_transport,TransportCategory,AirTransports);
							OO_SET(_airOperation,TransportOperation,VehicleCallups,_callups);
						};

						if (count _airDestination == 0) then { _airDestination = [_airSpawnpoint select 0, _area] call SPM_InfantryGarrison_FindOperationDropPosition };
						_destination = _airDestination;

						_request = [_callup select 1 select 1, _destination] call OO_CREATE(TransportRequestAir);
						OO_SET(_request,TransportRequest,OnArrive,SPM_InfantryGarrison_TransportOnArriveAir);
						OO_SET(_request,TransportRequest,OnSurrender,SPM_InfantryGarrison_TransportOnSurrenderAir);

						_airDropCount = _airDropCount + 1;
						if (_airDropCount >= MAX_AIR_DROPS) then { _weights set [2, 0.0] }; // No more air operations in this callup

						_operation = _airOperation;
					};
				};

				if (not OO_ISNULL(_request)) then
				{
					_callups deleteAt 0;

					private _clientData = [OO_REFERENCE(_category), _callup select 0]; // infantry unit type to spawn

					OO_SET(_request,TransportRequest,OnLoad,SPM_InfantryGarrison_TransportOnLoad);
					OO_SET(_request,TransportRequest,OnUpdate,SPM_InfantryGarrison_TransportOnUpdate);
					OO_SET(_request,TransportRequest,OnSalvage,SPM_InfantryGarrison_TransportOnSalvage);
					OO_SET(_request,TransportRequest,ClientData,_clientData);

					[_request] call OO_METHOD(_operation,TransportOperation,AddRequest);
				};
			};

			if (not OO_ISNULL(_seaOperation)) then
			{
				[_seaOperation] call OO_METHOD(_transport,TransportCategory,AddOperation);
				OO_GET(_category,InfantryGarrisonCategory,TransportOperations) pushBack _seaOperation;
			};
			if (not OO_ISNULL(_groundOperation)) then
			{
				[_groundOperation] call OO_METHOD(_transport,TransportCategory,AddOperation);
				OO_GET(_category,InfantryGarrisonCategory,TransportOperations) pushBack _groundOperation;
			};
			if (not OO_ISNULL(_airOperation)) then
			{
				[_airOperation] call OO_METHOD(_transport,TransportCategory,AddOperation);
				OO_GET(_category,InfantryGarrisonCategory,TransportOperations) pushBack _airOperation;
			};
		};
	};
};

OO_TRACE_DECL(SPM_InfantryGarrison_LeaveBuilding) =
{
	params ["_category", "_soldiers"];

	_soldiers = _soldiers select { alive _x };

	if (count _soldiers == 0) exitWith { grpNull };

	private _group = createGroup side (_soldiers select 0);
	_group setBehaviour (behaviour (_soldiers select 0));
	_group setCombatMode (combatMode (_soldiers select 0));
	_group setSpeedMode (speedMode (_soldiers select 0));

	{
		if ([_x] call SPM_Occupy_IsOccupyingUnit) then
		{
			[_x] call SPM_Occupy_UnchainUnit;
			[_x] call SPM_Occupy_FreeBuildingEntry;
		};

		[_x] join _group;
	} forEach _soldiers;

	_group
};

// Find a group of _number soldiers that we consider to be still housed that are occupying a single building.  Take them off the housed list and nothing more.  They will be used in place.
OO_TRACE_DECL(SPM_InfantryGarrison_BeginHouseDuty) =
{
	params ["_category", "_number"];

	private _housedUnits = OO_GET(_category,InfantryGarrisonCategory,HousedUnits);

	private _occupiedBuildings = [];
	private _building = objNull;
	{
		_building = [_x] call SPM_Occupy_GetOccupierBuilding;
		if (not isNull _building) then { _occupiedBuildings pushBackUnique _building };
	} forEach _housedUnits;

	private _side = OO_GET(_category,ForceCategory,SideEast);
	private _index = _occupiedBuildings findIf { count ([_x, _side] call SPM_Occupy_GetOccupiers) >= _number };

	if (_index == -1) exitWith { grpNull };

	private _occupiers = [_occupiedBuildings select _index] call SPM_Occupy_GetOccupiers;
	_occupiers = _occupiers apply { _x select 0 };

	_housedUnits = _housedUnits - _occupiers;
	OO_SET(_category,InfantryGarrisonCategory,HousedUnits,_housedUnits);

	group (_occupiers select 0) // Occupying units in the same building and in the same side are in one group
};

OO_TRACE_DECL(SPM_InfantryGarrison_EndHouseDuty) =
{
	params ["_category", "_group"];

	private _housedUnits = OO_GET(_category,InfantryGarrisonCategory,HousedUnits);
	{ _housedUnits pushBackUnique _x } forEach units _group;
};

OO_TRACE_DECL(SPM_InfantryGarrison_BeginTemporaryDuty) =
{
	params ["_category", "_number"];

	private _housedUnits = OO_GET(_category,InfantryGarrisonCategory,HousedUnits);

	// Only consider units that are safe and that are official members of the garrison (the garrison may have captives)
	private _sideEast = OO_GET(_category,ForceCategory,SideEast);
	_housedUnits = _housedUnits select { side _x == _sideEast && behaviour _x == "safe" };

	if (_number == -1 && count _housedUnits == 0) exitWith { grpNull };
	if (_number == -1) then { _number = count _housedUnits };
	if (count _housedUnits < _number) exitWith { grpNull };

	private _occupyingUnits = [];
	private _outdoorUnits = [];
	{
		if ([_x] call SPM_Occupy_IsOccupyingUnit) then { _occupyingUnits pushBack _x } else { _outdoorUnits pushBack _x };
	} forEach _housedUnits;

	// Make sure we send units not in buildings off to temporary duty first
	private _dutyUnits = (_outdoorUnits + _occupyingUnits) select [0, _number];

	_housedUnits = _housedUnits - _dutyUnits;
	OO_SET(_category,InfantryGarrisonCategory,HousedUnits,_housedUnits);

#ifdef OO_TRACE
	diag_log format ["SPM_InfantryGarrison_BeginTemporaryDuty: count _dutyUnits: %1", count _dutyUnits];
#endif
	[_category, _dutyUnits] call SPM_InfantryGarrison_LeaveBuilding
};

OO_TRACE_DECL(SPM_InfantryGarrison_EndTemporaryDuty) =
{
	params ["_category", "_dutyGroup"];

	if (isNull _dutyGroup) exitWith {};

	[_category, _dutyGroup, false, 0.0] call SPM_InfantryGarrison_GarrisonGroup;
};

OO_TRACE_DECL(SPM_InfantryGarrison_ReplaceUnit) =
{
	params ["_category", "_oldUnit", "_newUnit"];

	private _unitIndex = [_oldUnit, _newUnit] call OO_METHOD_PARENT(_category,ForceCategory,ReplaceUnit,ForceCategory);
	if (_unitIndex != -1) then
	{
		_oldUnit = OO_GET(_oldUnit,ForceUnit,Vehicle);
		_newUnit = OO_GET(_newUnit,ForceUnit,Vehicle);

		if ([_oldUnit] call SPM_Occupy_IsOccupyingUnit) then
		{
			[_oldUnit, _newUnit] call SPM_Occupy_ReplaceOccupier;
			if (side _oldUnit getFriend side _newUnit < 0.6) then { _newUnit setCaptive true };
		}
		else
		{
			private _newUnitGroup = group _newUnit;
			[_newUnit] join (group _oldUnit);
			if (count units _newUnitGroup == 0) then { deleteGroup _newUnitGroup };
		};

		private _housedUnits = OO_GET(_category,InfantryGarrisonCategory,HousedUnits);
		private _housedIndex = _housedUnits find _oldUnit;
		if (_housedIndex != -1) then { _housedUnits set [_housedIndex, _newUnit] };
	};

	_unitIndex
};

OO_TRACE_DECL(SPM_InfantryGarrison_Relocate) =
{
	params ["_category"];

	// Remove dead units from housed list
	private _housedUnits = OO_GET(_category,InfantryGarrisonCategory,HousedUnits);
	_housedUnits = _housedUnits select { alive _x };
	OO_SET(_category,InfantryGarrisonCategory,HousedUnits,_housedUnits);

	// Find out the odds of a given unit relocating
	private _relocateProbability = OO_GET(_category,InfantryGarrisonCategory,RelocateProbability);
	if (typeName _relocateProbability == "CODE") then
	{
		_relocateProbability = [_category] call _relocateProbability;
	};

	private _updateInterval = [_category] call OO_GET(_category,Category,GetUpdateInterval);
	private _relocations = _relocateProbability * _updateInterval * count _housedUnits;
	_relocations = _relocations min count _housedUnits;
	private _totalRelocations = floor _relocations;
	_relocations = _relocations - _totalRelocations;
	if (random 1 < _relocations) then { _totalRelocations = _totalRelocations + 1 };

	for "_i" from 1 to _totalRelocations do
	{
		private _unit = selectRandom _housedUnits;
		if (behaviour _unit == "safe") then
		{
			private _waypoints = waypoints _unit;
			if (count _waypoints == 1 && { (waypointPosition (_waypoints select 0)) select 0 == 0 }) then
			{
				private _movingUnits = [_unit];

				// If the soldier has any others in his group, grab one and send the two of them to a new building
				private _groupUnits = (units group _unit) - [_unit];
				if (count _groupUnits > 0) then
				{
					_movingUnits pushBack (selectRandom _groupUnits);
				};

				private _group = [_category, _movingUnits] call SPM_InfantryGarrison_LeaveBuilding;
				if (not isNull _group) then { [_category, _group, false, 0.1] call SPM_InfantryGarrison_GarrisonGroup }; // Stay local, but still allow long range moves
			};
		};
	};
};

OO_TRACE_DECL(SPM_InfantryGarrison_CallMortars) =
{
	params ["_category"];

	if (diag_tickTime < OO_GET(_category,InfantryGarrisonCategory,_MortarTime)) exitWith {};

	OO_SET(_category,InfantryGarrisonCategory,_MortarTime,diag_tickTime+20);

	private _mortars = OO_GET(_category,InfantryGarrisonCategory,Mortars);

	if (count _mortars == 0) exitWith {};

	private _area = OO_GET(_category,ForceCategory,Area);
	private _outerRadius = OO_GET(_area,StrongpointArea,OuterRadius);

	private _westRatings = [1000] call OO_METHOD(_category,ForceCategory,GetForceLevelsWest);
	if (count _westRatings >= 3) then
	{
		private _westUnits = _westRatings apply { OO_GET(_x,ForceRating,Vehicle) } select { lifeState _x in ["HEALTHY", "INJURED"] };

		private _westClusters = [_westUnits, ((count _westUnits) / 3) min 5] call JB_fnc_unitClusters;
		_westClusters = _westClusters select { count (_x select 2) >= 3 };

		private _soldierDensity = 1 / 1600; // 1 soldier per 40m*40m
		_westClusters = _westClusters apply { [count (_x select 2) / (pi * (_x select 3)^2) , _x select 0, _x select 3, _x select 2] };
		_westClusters = _westClusters select { _x select 0 > _soldierDensity };

		if (count _westClusters > 0) then
		{
			_westClusters = _westClusters apply { [0, _x select 1, _x select 2, _x select 3, objNull] };

			private _leaders = _forceUnits apply { OO_GET(_x,ForceUnit,Vehicle) } select { alive _x && (_x == leader group _x) };

			{
				private _cluster = _x;
				private _numberSpotted = 0;

				{
					private _leader = _x;
					private _numberSpotted = ({ (_leader knowsAbout _x) >= 1.5 } count (_cluster select 3));
					if (_numberSpotted > _cluster select 0) then
					{
						_cluster set [0, _numberSpotted];
						_cluster set [4, _leader];
					}
				} forEach _leaders;
			} forEach _westClusters;

			_westClusters sort false; // Descending, number of spotted soldiers in cluster

			_mortars = _mortars apply { _x }; // Shallow copy so we can fiddle with the copy ('+' is a deep copy)

			{
				private _targetPosition = _x select 1;

				// Introduce spotting/reporting inaccuracy of 10% (a target 300 meters away will be mistargeted by up to 30 meters)
				private _wobble = (_targetPosition distance (_x select 4)) * 0.2;
				_targetPosition = _targetPosition vectorAdd [-_wobble / 2 + random _wobble, -_wobble / 2 + random _wobble, 0];

				private _fireMission = [_targetPosition, [[0, "8Rnd_82mm_Mo_shells"]]] call OO_CREATE(MortarFireMission);
				private _mortar = _mortars deleteAt (floor random count _mortars);
				[_fireMission] call OO_METHOD(_mortar,MortarCategory,AddFireMission);

				// Keep the mortar as a candidate if it can still fire
				if ([_fireMission] call OO_METHOD(_mortar,MortarCategory,CanExecuteFireMission)) then { _mortars pushBack _mortar };

				if (count _mortars == 0) exitWith {};
			} forEach (_westClusters select { _x select 0 >= 3 }); // Must be at least 3 enemies in the cluster
		};
	};
};

OO_TRACE_DECL(SPM_InfantryGarrison_Update) =
{
	params ["_category"];

	[] call OO_METHOD_PARENT(_category,Category,Update,ForceCategory);

	if (OO_GET(_category,Category,UpdateIndex) == 1) then
	{
		private _callups = [];
		private _reserves = 0;

		switch (true) do
		{
			case (OO_GET(_category,InfantryGarrisonCategory,PlanReserves) > 0): { _callups = OO_GET(_category,InfantryGarrisonCategory,PlanCallupsEast); _reserves = OO_GET(_category,InfantryGarrisonCategory,PlanReserves) };
			case (OO_GET(_category,InfantryGarrisonCategory,InitialReserves) > 0): { _callups = OO_GET(_category,InfantryGarrisonCategory,InitialCallupsEast); _reserves = OO_GET(_category,InfantryGarrisonCategory,InitialReserves) };
			default { _callups = OO_GET(_category,ForceCategory,CallupsEast); _reserves = OO_GET(_category,ForceCategory,Reserves) };
		};

		[_category, _callups, _reserves * 1.2] call SPM_InfantryGarrison_PlanOccupation; // The 1.2 is there so we plan for some extra room to allow units to relocate

		[_category] call SPM_InfantryGarrison_CreateInitialForce;
	};

	// Remove dead units
	private _forceUnits = OO_GET(_category,ForceCategory,ForceUnits) select { alive OO_GET(_x,ForceUnit,Vehicle) };
	OO_SET(_category,ForceCategory,ForceUnits,_forceUnits);

	// Remove units that have wandered onto a base
	if (OO_GET(_category,InfantryGarrisonCategory,_DeleteStrays)) then { [_forceUnits, 0, OO_GET(_category,ForceCategory,SideWest)] call SPM_Force_DeleteEnemiesOnBases };

	// Call in support assets on enemies
	[_category] call SPM_InfantryGarrison_CallMortars;

	// At interals, have infantry wander around between different buildings
	[_category] call SPM_InfantryGarrison_Relocate;

	// Balance the garrison
	private _balanceTime = OO_GET(_category,InfantryGarrisonCategory,_BalanceTime);
	if (diag_tickTime > _balanceTime) then
	{
		[_category] call SPM_InfantryGarrison_Balance;

		private _balanceInterval = OO_GET(_category,InfantryGarrisonCategory,BalanceInterval);
		private _balanceTime = diag_tickTime + (_balanceInterval select 0) + (random ((_balanceInterval select 1) - (_balanceInterval select 0)));
		OO_SET(_category,InfantryGarrisonCategory,_BalanceTime,_balanceTime);
	};
};

OO_TRACE_DECL(SPM_InfantryGarrison_Create) =
{
	params ["_category", "_area"];

	OO_SET(_category,ForceCategory,Area,_area);
	OO_SET(_category,ForceCategory,RatingsWest,SPM_InfantryGarrison_RatingsWest);
	OO_SET(_category,ForceCategory,RatingsEast,SPM_InfantryGarrison_RatingsEast);
	OO_SET(_category,ForceCategory,CallupsEast,SPM_InfantryGarrison_CallupsEast);

	// If the edge of the garrison is within 1500 meters of a base, flag the garrison to delete its strays if they wander onto a base
	private _position = OO_GET(_area,StrongpointArea,Position);
	private _outerRadius = OO_GET(_area,StrongpointArea,OuterRadius);
	private _blacklist = [_outerRadius + 1500, -1, -1] call SERVER_OperationBlacklist;
	if (_blacklist findIf { [_position, _x] call SPM_Util_PositionInArea } >= 0) then { OO_SET(_category,InfantryGarrisonCategory,_DeleteStrays,true) };
};

OO_TRACE_DECL(SPM_InfantryGarrison_Delete) =
{
	params ["_category"];

	[] call OO_METHOD_PARENT(_category,Root,Delete,ForceCategory);
};

// Civilian preferred buildings
//	_buildings = _buildings select { getText (configFile >> "CfgVehicles" >> typeOf _x >> "vehicleClass") in ["Structures_Village", "Structures_Town"] };

//Syndikat preferred buildings
//	_buildings = _buildings select { getText (configFile >> "CfgVehicles" >> typeOf _x >> "vehicleClass") in ["Structures_Village", "Structures_Town"] };


private _transportOperationsNull = [OO_NULL,OO_NULL,OO_NULL];
private _defaultOccupationLimits = [1,4];

OO_BEGIN_SUBCLASS(InfantryGarrisonCategory,ForceCategory);
	OO_OVERRIDE_METHOD(InfantryGarrisonCategory,Root,Create,SPM_InfantryGarrison_Create);
	OO_OVERRIDE_METHOD(InfantryGarrisonCategory,Root,Delete,SPM_InfantryGarrison_Delete);
	OO_OVERRIDE_METHOD(InfantryGarrisonCategory,Category,Update,SPM_InfantryGarrison_Update);
	OO_OVERRIDE_METHOD(InfantryGarrisonCategory,ForceCategory,ReplaceUnit,SPM_InfantryGarrison_ReplaceUnit);
	OO_DEFINE_METHOD(InfantryGarrisonCategory,BeginTemporaryDuty,SPM_InfantryGarrison_BeginTemporaryDuty);
	OO_DEFINE_METHOD(InfantryGarrisonCategory,EndTemporaryDuty,SPM_InfantryGarrison_EndTemporaryDuty);
	OO_DEFINE_METHOD(InfantryGarrisonCategory,BeginHouseDuty,SPM_InfantryGarrison_BeginHouseDuty);
	OO_DEFINE_METHOD(InfantryGarrisonCategory,EndHouseDuty,SPM_InfantryGarrison_EndHouseDuty);
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,InitialReserves,"SCALAR",0); // Reserves to be placed into the garrison right away
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,InitialCallupsEast,"ARRAY",SPM_InfantryGarrison_InitialCallupsEast); // Unit types to be placed into the garrison right away
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,PlanReserves,"SCALAR",0); // Occupation planning based on this reserve level (if greater than 0)
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,PlanCallupsEast,"ARRAY",[]); // Occupation planning based on these callups
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,InitialForceCreated,"BOOL",false);
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,ActivityBorder,"BOOL",0); // A buffer distance at which the infantry arrives, is discounted if it departs, etc.
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,OccupationLimits,"ARRAY",_defaultOccupationLimits); // Per building, the minimum and maximum number of troops to house
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,RelocateProbability,"SCALAR",0.000); // Per second, the odds that a garrison soldier will relocate (CODE also allowed)
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,HouseOutdoors,"BOOL",true);
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,Transport,"#OBJ",OO_NULL);
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,TransportBySea,"SCALAR",0.8); // The defaults produce 0.8 probability of sea, 0.2*0.5=0.1 probability of ground and 0.2*0.5*1.0=0.1 probability of air, assuming that all three types of transport are available and practical
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,TransportByGround,"SCALAR",0.5); // If sea transport is not practical, then it's 0.5 probability of ground and 0.5*1.0=0.5 probability of air
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,TransportByAir,"SCALAR",1.0); // If ground transport is not practical, then it's 1.0 probability of air
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,TransportOperations,"ARRAY",[]); // Active transport operations
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,Mortars,"ARRAY",[]);
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,_MortarTime,"SCALAR",0);
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,_BalanceTime,"SCALAR",0);
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,BalanceInterval,"ARRAY",BALANCE_INTERVAL);
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,GarrisonBuildings,"ARRAY",[]);
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,OutdoorPositions,"ARRAY",[]);
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,UrbanThreshhold,"SCALAR",0.6); // Fraction of units that must be housed if the operation is to be considered urban
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,IsUrbanEnvironment,"BOOL",false); // Whether the garrison is occupying an urban environment
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,HousingPreference,"SCALAR",0.2); // 0.0 - 1.0. The larger the number, the greater preference for buildings in the outermost part of the garrison area.  A -1.0 value gives uniform distribution.
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,HousedUnits,"ARRAY",[]);
	OO_DEFINE_PROPERTY(InfantryGarrisonCategory,_DeleteStrays,"BOOL",false);
OO_END_SUBCLASS(InfantryGarrisonCategory);
