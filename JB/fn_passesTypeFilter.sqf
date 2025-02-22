private _vehicleType = param [0, "", [""]];
private _filter = param [1, [], [[]]];
private _config = param [2, "CfgVehicles", [""]];

_passesFilter = false;

private _vehicleTypeLength = count _vehicleType;
private _pattern = "";
private _matchesPattern = false;

{
	_pattern = _x select 0;

	private _wildcard = _pattern find "*";
	if (_wildcard == -1) then
	{
		_matchesPattern = _vehicleType isKindOf [_pattern, configFile >> _config];
	}
	else
	{
		if (_vehicleTypeLength >= _wildcard) then
		{
			_matchesPattern = (_vehicleType select [0, _wildcard]) == (_pattern select [0, _wildcard]);
		};
	};
	if (_matchesPattern) exitWith { if (count _x == 2) then { _passesFilter = _x select 1 } else { _passesFilter = _x select [1,2] } };
} forEach _filter;

_passesFilter