import Hub from './hub/Hub';
import VibeWords from './games/words/VibeWords';
import VibeTrio from './games/trio/VibeTrio';
import { usePath } from './router';

/**
 * Every screen in the suite, one path each.
 *
 * Anything the switch does not recognise falls through to the hub, so an old
 * bookmark — play.vibegames.party used to be Vibe Words and nothing else — lands
 * somewhere useful rather than on a 404.
 */
function App() {
  const path = usePath();

  switch (path) {
    case '/words':
      return <VibeWords />;
    case '/trio':
      return <VibeTrio />;
    case '/':
      return <Hub />;
    default:
      return <Hub />;
  }
}

export default App;
