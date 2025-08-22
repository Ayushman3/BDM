// rotation_validator.dart
import 'rotation_helper.dart';
import 'package:badminton_app/court/court_geometry.dart';

/// Throws ArgumentError with a clear message when an invariant is violated.
/// Call after every rotation transition in dev/test builds (or wrap with asserts).

void validateServingKey(ServingState serving) {
  const allowed = {'A_FRONT','A_BACK','B_FRONT','B_BACK'};
  if (!allowed.contains(serving.servingKey)) {
    throw ArgumentError('Invalid servingKey: ${serving.servingKey}');
  }
}

void validateAnchors(CourtPositions anchors) {
  final coords = <Pct>[anchors.aFront, anchors.aBack, anchors.bFront, anchors.bBack];
  for (final p in coords) {
    if (p.x.isNaN || p.y.isNaN) {
      throw ArgumentError('Anchor has NaN coordinates');
    }
    if (p.x < 0 || p.x > 1 || p.y < 0 || p.y > 1) {
      throw ArgumentError('Anchor out of bounds (0..1): (${p.x}, ${p.y})');
    }
  }
}

void validatePose(CourtPose pose) {
  validateServingKey(ServingState(
    pose.servingKey.startsWith('A') ? Team.A : Team.B,
    pose.servingKey,
  ));
  validateAnchors(pose.anchors);
}

/// High-level invariant check for RotationState after any update.
void validateRotationState(RotationState s) {
  // 1) Serving team must match servingKey prefix
  final prefix = s.serving.servingKey.substring(0,1);
  final teamFromKey = prefix == 'A' ? Team.A : Team.B;
  if (teamFromKey != s.serving.team) {
    throw ArgumentError('Serving team (${s.serving.team}) '
        'does not match servingKey (${s.serving.servingKey})');
  }

  // 2) Pose validity
  validatePose(s.pose);

  // 3) Players mapping not empty (basic sanity)
  if (s.players.aFront.isEmpty ||
      s.players.aBack.isEmpty ||
      s.players.bFront.isEmpty ||
      s.players.bBack.isEmpty) {
    throw ArgumentError('Player labels/ids must be non-empty for all four roles');
  }
}

