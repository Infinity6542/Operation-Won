import 'package:test/test.dart';
import 'package:operation_won/home.dart';

void main() {
  // Experimental, incomplete
  final MasterState handler = MasterState();
  test('Test if _isMuted changes when pausing/resuming media', () {
    final mediaPlayer = AudioHandler();
    expect(handler._isMuted, isFalse);

    mediaPlayer.pause();
    expect(handler._isMuted, isTrue);

    mediaPlayer.play();
    expect(handler._isMuted, isFalse);
  });
}
