# Patches the scratch copy so the face renders a fixed time, sample data and
# the colours/fields from ShotConfig (store screenshots only).
use strict;
local $/;
my $dir = shift;

sub edit {
    my ($file, $code) = @_;
    open my $in, '<', "$dir/source/$file" or die $!;
    my $text = <$in>;
    close $in;
    $text = $code->($text);
    open my $out, '>', "$dir/source/$file" or die $!;
    print $out $text;
    close $out;
}

edit('ApexMetrics.mc', sub {
    my $t = shift;
    $t =~ s/function fieldValue\(/function realFieldValue(/ or die 'fieldValue';
    $t =~ s/function arcFraction\(/function realArcFraction(/ or die 'arcFraction';
    $t =~ s/function arcReadout\(/function realArcReadout(/ or die 'arcReadout';
    $t =~ s/\}\s*\z/
    function fieldValue(id as Number, clock as System.ClockTime, awake as Boolean) as String {
        return id == ApexMetrics.F_SEC ? ApexFormat.twoDigits(clock.sec) : ShotSamples.field(id);
    }

    function arcFraction(id as Number) as Float or Null {
        return ShotSamples.arcFraction(id);
    }

    function arcReadout(id as Number) as String {
        return ShotSamples.arcReadout(id);
    }
}
/ or die 'class end';
    return $t;
});

edit('ApexFaceView.mc', sub {
    my $t = shift;
    $t =~ s/var clock = System\.getClockTime\(\);/var clock = ShotSamples.clock();/ or die 'clock';
    $t =~ s/var now = Gregorian\.info\(Time\.now\(\), Time\.FORMAT_SHORT\);/var now = ShotSamples.now();/ or die 'now';
    $t =~ s/(    private function burnInProtection\(\) as Boolean \{\n)/$1        return true;\n/ or die 'burnin';
    $t =~ s/(        mEditMode = editMode;\n(?:.*\n)*?        loadSettings\(\);\n)/$1        applyShot();\n/ or die 'init';
    $t =~ s/(    function loadSettings\(\) as Void \{)/    private function applyShot() as Void {
        mAwake = !ShotConfig.AOD;
        mDayAccent = ShotConfig.ACCENT;
        mDayNumerals = ApexLayout.numeralColor(ShotConfig.NUMERALS, mDayAccent);
        mDayInk = 0xF4F4EF;
        mDayDim = 0xB0B0AA;
        mFieldIds = ShotConfig.FIELDS;
        mFieldComplications = [null, null, null];
        mArcId = ShotConfig.ARC;
        mNightMode = ShotConfig.NIGHT ? ApexLayout.NIGHT_ON : ApexLayout.NIGHT_OFF;
        mNight = ShotConfig.NIGHT;
        applyPalette();
    }

$1/ or die 'loadSettings';
    return $t;
});
