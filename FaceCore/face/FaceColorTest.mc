import Toybox.Lang;
import Toybox.Test;

(:test)
module FaceColorTest {

    (:test)
    function nearGreysBecomeNeutral(logger as Logger) as Boolean {
        return FaceColor.mipGrey(0x26282B) == 0x555555      // would round to navy
            && FaceColor.mipGrey(0x050505) == 0x000000
            && FaceColor.mipGrey(0x141516) == 0x000000
            && FaceColor.mipGrey(0x8D939A) == 0xAAAAAA
            && FaceColor.mipGrey(0xF2F2F0) == 0xFFFFFF;
    }

    (:test)
    function coloursStayAsTheyAre(logger as Logger) as Boolean {
        return FaceColor.mipGrey(0xFF6A13) == 0xFF6A13
            && FaceColor.mipGrey(0x3FD0C9) == 0x3FD0C9
            && FaceColor.mipGrey(0x5A2222) == 0x5A2222;
    }
}
