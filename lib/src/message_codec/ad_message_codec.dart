import 'package:audienzz_sdk_flutter/src/entities/ad_error.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_format.dart';
import 'package:audienzz_sdk_flutter/src/entities/ad_size.dart';
import 'package:audienzz_sdk_flutter/src/entities/api_parameter.dart';
import 'package:audienzz_sdk_flutter/src/entities/exceptions/ad_message_codec_reading_exception.dart';
import 'package:audienzz_sdk_flutter/src/entities/initialization_status.dart';
import 'package:audienzz_sdk_flutter/src/entities/min_size_percentage.dart';
import 'package:audienzz_sdk_flutter/src/entities/reward_item.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/placement.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/playback_method.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/protocol.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/video_bitrate.dart';
import 'package:audienzz_sdk_flutter/src/entities/video_parameters/video_duration.dart';
import 'package:flutter/services.dart';

final class AdMessageCodec extends StandardMessageCodec {
  static const int _valueInitializationStatus = 128;
  static const int _valueAdSize = 129;
  static const int _valueAdError = 130;
  static const int _valueRewardItem = 131;
  static const int _valueAdFormat = 132;
  static const int _valueApiParameter = 133;
  static const int _valueProtocol = 134;
  static const int _valuePlacement = 135;
  static const int _valuePlaybackMethod = 136;
  static const int _valueVideoBitrate = 137;
  static const int _valueVideoDuration = 138;
  static const int _valueMinSizePercentage = 143;

  @override
  void writeValue(WriteBuffer buffer, dynamic value) {
    if (value is InitializationStatus) {
      buffer.putUint8(_valueInitializationStatus);
      writeValue(buffer, value.code);
    } else if (value is AdSize) {
      buffer.putUint8(_valueAdSize);
      writeValue(buffer, value.width);
      writeValue(buffer, value.height);
    } else if (value is AdError) {
      buffer.putUint8(_valueAdError);
      writeValue(buffer, value.code);
      writeValue(buffer, value.message);
    } else if (value is RewardItem) {
      buffer.putUint8(_valueRewardItem);
      writeValue(buffer, value.amount);
      writeValue(buffer, value.type);
    } else if (value is AdFormat) {
      buffer.putUint8(_valueAdFormat);
      writeValue(buffer, value.code);
    } else if (value is ApiParameter) {
      buffer.putUint8(_valueApiParameter);
      writeValue(buffer, value.code);
    } else if (value is Protocol) {
      buffer.putUint8(_valueProtocol);
      writeValue(buffer, value.code);
    } else if (value is Placement) {
      buffer.putUint8(_valuePlacement);
      writeValue(buffer, value.code);
    } else if (value is PlaybackMethod) {
      buffer.putUint8(_valuePlaybackMethod);
      writeValue(buffer, value.code);
    } else if (value is VideoBitrate) {
      buffer.putUint8(_valueVideoBitrate);
      writeValue(buffer, value.min);
      writeValue(buffer, value.max);
    } else if (value is VideoDuration) {
      buffer.putUint8(_valueVideoDuration);
      writeValue(buffer, value.min);
      writeValue(buffer, value.max);
    } else if (value is MinSizePercentage) {
      buffer.putUint8(_valueMinSizePercentage);
      writeValue(buffer, value.width);
      writeValue(buffer, value.height);
    } else {
      super.writeValue(buffer, value);
    }
  }

  @override
  dynamic readValueOfType(dynamic type, ReadBuffer buffer) {
    switch (type) {
      case _valueInitializationStatus:
        {
          final initializationStatusCode =
              readValueOfType(buffer.getUint8(), buffer) as int?;

          if (initializationStatusCode != null) {
            return InitializationStatus.fromCode(initializationStatusCode);
          }

          throw const AdMessageCodecReadingException();
        }

      case _valueAdSize:
        {
          final width = readValueOfType(buffer.getUint8(), buffer) as num?;
          final height = readValueOfType(buffer.getUint8(), buffer) as num?;

          if (width != null && height != null) {
            return AdSize(height: height.toInt(), width: width.toInt());
          }

          throw const AdMessageCodecReadingException();
        }
      case _valueAdError:
        {
          final code = readValueOfType(buffer.getUint8(), buffer) as int?;
          final message = readValueOfType(buffer.getUint8(), buffer) as String?;

          if (code != null && message != null) {
            return AdError(code: code, message: message);
          }

          throw const AdMessageCodecReadingException();
        }

      case _valueRewardItem:
        {
          final amount = readValueOfType(buffer.getUint8(), buffer) as num?;
          final type = readValueOfType(buffer.getUint8(), buffer) as String?;

          if (amount != null && type != null) {
            return RewardItem(amount: amount, type: type);
          }

          throw const AdMessageCodecReadingException();
        }

      case _valueAdFormat:
        {
          final code = readValueOfType(buffer.getUint8(), buffer) as num?;

          if (code != null) {
            return AdFormat.fromCode(code.toInt());
          }

          throw const AdMessageCodecReadingException();
        }
      case _valueApiParameter:
        {
          final code = readValueOfType(buffer.getUint8(), buffer) as num?;

          if (code != null) {
            return ApiParameter.fromCode(code.toInt());
          }

          throw const AdMessageCodecReadingException();
        }

      case _valueProtocol:
        {
          final code = readValueOfType(buffer.getUint8(), buffer) as num?;

          if (code != null) {
            return Protocol.fromCode(code.toInt());
          }

          throw const AdMessageCodecReadingException();
        }
      case _valuePlacement:
        {
          final code = readValueOfType(buffer.getUint8(), buffer) as num?;

          if (code != null) {
            return Placement.fromCode(code.toInt());
          }

          throw const AdMessageCodecReadingException();
        }
      case _valuePlaybackMethod:
        {
          final code = readValueOfType(buffer.getUint8(), buffer) as num?;

          if (code != null) {
            return PlaybackMethod.fromCode(code.toInt());
          }

          throw const AdMessageCodecReadingException();
        }
      case _valueVideoBitrate:
        {
          final minBitrate = readValueOfType(buffer.getUint8(), buffer) as num?;
          final maxBitrate = readValueOfType(buffer.getUint8(), buffer) as num?;

          if (minBitrate != null && maxBitrate != null) {
            return VideoBitrate(
              min: minBitrate.toInt(),
              max: maxBitrate.toInt(),
            );
          }

          throw const AdMessageCodecReadingException();
        }

      case _valueVideoDuration:
        {
          final minDuration =
              readValueOfType(buffer.getUint8(), buffer) as num?;
          final maxDuration =
              readValueOfType(buffer.getUint8(), buffer) as num?;

          if (minDuration != null && maxDuration != null) {
            return VideoDuration(
              min: minDuration.toInt(),
              max: maxDuration.toInt(),
            );
          }

          throw const AdMessageCodecReadingException();
        }
      case _valueMinSizePercentage:
        {
          final width = readValueOfType(buffer.getUint8(), buffer) as num?;
          final height = readValueOfType(buffer.getUint8(), buffer) as num?;

          if (width != null && height != null) {
            return MinSizePercentage(
              width: width.toInt(),
              height: height.toInt(),
            );
          }

          throw const AdMessageCodecReadingException();
        }
      case _:
        return super.readValueOfType(type as int, buffer);
    }
  }
}
