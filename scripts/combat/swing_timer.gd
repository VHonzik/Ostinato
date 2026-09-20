class_name SwingTimer
extends RefCounted

## FR-014: retain fractional delay, but never bank attacks while inactive.
var remaining: float = 0.0
var _active: bool = false


func advance(active: bool, interval: float) -> int:
	interval = maxf(0.01, interval)
	if not active:
		remaining = maxf(0.0, remaining - 1.0)
		_active = false
		return 0
	if not _active:
		remaining = maxf(0.0, remaining - 1.0)
		_active = true
		if remaining > 0.000001:
			return 0
		remaining = interval
		return 1
	remaining -= 1.0
	var swings := 0
	while remaining <= 0.000001:
		swings += 1
		remaining += interval
	return swings
