@tool
extends RefCounted
## Pure drag geometry. All points and factors are relative to the press snapshot.

const MIN_FACTOR := 0.001


static func resize_transform(start: Transform2D, bounds: Rect2, handle: int,
		local_delta: Vector2, proportional: bool, screen_basis: Transform2D) -> Transform2D:
	var axes := Vector2(-1 if handle in [0, 6, 7] else (1 if handle in [2, 3, 4] else 0),
		-1 if handle in [0, 1, 2] else (1 if handle in [4, 5, 6] else 0))
	var anchor := bounds.get_center() - axes * bounds.size * 0.5
	var diagonal := axes * bounds.size
	var factor := Vector2.ONE
	if axes.x != 0:
		factor.x += local_delta.x / diagonal.x
	if axes.y != 0:
		factor.y += local_delta.y / diagonal.y
	if proportional and axes.x != 0 and axes.y != 0:
		# Project onto the corner's screen-space diagonal: continuous even when
		# the pointer crosses between the horizontal and vertical dominant axes.
		var screen_diagonal := screen_basis.basis_xform(diagonal)
		var screen_delta := screen_basis.basis_xform(local_delta)
		var uniform := 1.0 + screen_delta.dot(screen_diagonal) / screen_diagonal.length_squared()
		factor = Vector2.ONE * maxf(MIN_FACTOR, uniform)
	else:
		factor.x = maxf(MIN_FACTOR, factor.x)
		factor.y = maxf(MIN_FACTOR, factor.y)
	# Clamp at the opposite side rather than flipping the model through zero.
	return start * Transform2D(Vector2(factor.x, 0), Vector2(0, factor.y), anchor - anchor * factor)
