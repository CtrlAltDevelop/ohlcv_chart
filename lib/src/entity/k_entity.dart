import 'atr_entity.dart';
import 'candle_entity.dart';
import 'cci_entity.dart';
import 'dmi_entity.dart';
import 'kdj_entity.dart';
import 'macd_entity.dart';
import 'mfi_entity.dart';
import 'obv_entity.dart';
import 'rsi_entity.dart';
import 'rw_entity.dart';
import 'volume_entity.dart';

class KEntity
    with
        CandleEntity,
        VolumeEntity,
        KDJEntity,
        RSIEntity,
        WREntity,
        CCIEntity,
        MACDEntity,
        ATREntity,
        OBVEntity,
        MFIEntity,
        DMIEntity {}
