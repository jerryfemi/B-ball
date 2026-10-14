import "./index.css";
import "./preload";
import { Composition } from "remotion";
import { BBallPromo } from "./BBallPromo";

export const RemotionRoot: React.FC = () => {
  return (
    <>
      <Composition
        id="BBallPromo"
        component={BBallPromo}
        durationInFrames={1970}
        fps={30}
        width={1920}
        height={1080}
      />
    </>
  );
};
