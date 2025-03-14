package com.audienzz.audienzz_sdk_flutter.message_codec

import android.content.Context
import com.audienzz.audienzz_sdk_flutter.entities.AdFormat
import com.audienzz.audienzz_sdk_flutter.entities.InitializationStatus
import com.audienzz.audienzz_sdk_flutter.entities.MinSizePercentage
import com.audienzz.audienzz_sdk_flutter.entities.RewardAdItem
import com.audienzz.audienzz_sdk_flutter.entities.VideoBitrate
import com.audienzz.audienzz_sdk_flutter.entities.VideoDuration
import com.google.android.gms.ads.AdError
import com.google.android.gms.ads.AdSize
import io.flutter.plugin.common.StandardMessageCodec
import org.audienzz.mobile.AudienzzContentObject
import org.audienzz.mobile.AudienzzContentObject.AudienzzProducerObject
import org.audienzz.mobile.AudienzzDataObject
import org.audienzz.mobile.AudienzzSignals
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer

class AdMessageCodec(private var context: Context) : StandardMessageCodec() {
    fun setContext(context: Context) {
        this.context = context
    }

    override fun writeValue(stream: ByteArrayOutputStream, value: Any?) {
        when (value) {
            is InitializationStatus -> {
                stream.write(VALUE_INITIALIZATION_STATUS.toInt())

                writeValue(
                    stream, when (value) {
                        InitializationStatus.SUCCESS -> 0
                        InitializationStatus.FAIL -> 1
                    }
                )
            }

            is AdSize -> {
                stream.write(VALUE_AD_SIZE.toInt())
                writeValue(stream, value.width)
                writeValue(stream, value.height)
            }

            is AdError -> {
                stream.write(VALUE_AD_ERROR.toInt())
                writeValue(stream, value.code)
                writeValue(stream, value.message)
            }

            is RewardAdItem -> {
                stream.write(VALUE_REWARD_ITEM.toInt())
                writeValue(stream, value.amount)
                writeValue(stream, value.type)
            }

            is AdFormat -> {
                stream.write(VALUE_AD_FORMAT.toInt())
                writeValue(
                    stream, when (value) {
                        AdFormat.BANNER -> 0
                        AdFormat.VIDEO -> 1
                        AdFormat.BANNER_AND_VIDEO -> 2
                    }
                )
            }

            is AudienzzSignals.Api -> {
                stream.write(VALUE_API_PARAMETER.toInt())
                writeValue(
                    stream, when (value) {
                        AudienzzSignals.Api.VPAID_1 -> 0
                        AudienzzSignals.Api.VPAID_2 -> 1
                        AudienzzSignals.Api.MRAID_1 -> 2
                        AudienzzSignals.Api.ORMMA -> 3
                        AudienzzSignals.Api.MRAID_2 -> 4
                        AudienzzSignals.Api.MRAID_3 -> 5
                        AudienzzSignals.Api.OMID_1 -> 6
                    }
                )
            }

            is AudienzzSignals.Protocols -> {
                stream.write(VALUE_PROTOCOL.toInt())
                writeValue(
                    stream, when (value) {
                        AudienzzSignals.Protocols.VAST_1_0 -> 0
                        AudienzzSignals.Protocols.VAST_2_0 -> 1
                        AudienzzSignals.Protocols.VAST_3_0 -> 2
                        AudienzzSignals.Protocols.VAST_1_0_WRAPPER -> 3
                        AudienzzSignals.Protocols.VAST_2_0_WRAPPER -> 4
                        AudienzzSignals.Protocols.VAST_3_0_WRAPPER -> 5
                        AudienzzSignals.Protocols.VAST_4_0 -> 6
                        AudienzzSignals.Protocols.VAST_4_0_WRAPPER -> 7
                        AudienzzSignals.Protocols.DAAST_1_0 -> 8
                        AudienzzSignals.Protocols.DAAST_1_0_WRAPPER -> 9
                    }
                )
            }

            is AudienzzSignals.Placement -> {
                stream.write(VALUE_PLACEMENT.toInt())
                writeValue(
                    stream, when (value) {
                        AudienzzSignals.Placement.InStream -> 0
                        AudienzzSignals.Placement.InBanner -> 1
                        AudienzzSignals.Placement.InArticle -> 2
                        AudienzzSignals.Placement.InFeed -> 3
                        AudienzzSignals.Placement.Interstitial -> 4
                        AudienzzSignals.Placement.Slider -> 5
                        AudienzzSignals.Placement.Floating -> 6
                    }
                )
            }

            is AudienzzSignals.PlaybackMethod -> {
                stream.write(VALUE_PLAYBACK_METHOD.toInt())
                writeValue(
                    stream, when (value) {
                        AudienzzSignals.PlaybackMethod.AutoPlaySoundOn -> 0
                        AudienzzSignals.PlaybackMethod.AutoPlaySoundOff -> 1
                        AudienzzSignals.PlaybackMethod.ClickToPlay -> 2
                        AudienzzSignals.PlaybackMethod.MouseOver -> 3
                        AudienzzSignals.PlaybackMethod.EnterSoundOn -> 4
                        AudienzzSignals.PlaybackMethod.EnterSoundOff -> 5
                    }
                )
            }

            is VideoBitrate -> {
                stream.write(VALUE_VIDEO_BITRATE.toInt())
                writeValue(stream, value.minBitrate)
                writeValue(stream, value.maxBitrate)
            }

            is VideoDuration -> {
                stream.write(VALUE_VIDEO_DURATION.toInt())
                writeValue(stream, value.minDuration)
                writeValue(stream, value.maxDuration)
            }

            is AudienzzContentObject -> {
                stream.write(VALUE_APP_CONTENT.toInt())
                writeValue(stream, value.id)
                writeValue(stream, value.episode)
                writeValue(stream, value.title)
                writeValue(stream, value.series)
                writeValue(stream, value.season)
                writeValue(stream, value.artist)
                writeValue(stream, value.genre)
                writeValue(stream, value.album)
                writeValue(stream, value.isrc)
                writeValue(stream, value.url)
                writeValue(stream, value.categories)
                writeValue(stream, value.productionQuality)
                writeValue(stream, value.context)
                writeValue(stream, value.contentRating)
                writeValue(stream, value.userRating)
                writeValue(stream, value.qaMediaRating)
                writeValue(stream, value.keywords)
                writeValue(stream, value.liveStream)
                writeValue(stream, value.sourceRelationship)
                writeValue(stream, value.length)
                writeValue(stream, value.language)
                writeValue(stream, value.embeddable)
                writeValue(stream, value.getDataList())
                writeValue(stream, value.producer)
            }

            is AudienzzDataObject -> {
                stream.write(VALUE_DATA_OBJECT.toInt())
                writeValue(stream, value.id)
                writeValue(stream, value.name)
                writeValue(stream, value.getSegments())
            }

            is AudienzzDataObject.AudienzzSegmentObject -> {
                stream.write(VALUE_DATA_OBJECT_SEGMENT.toInt())
                writeValue(stream, value.id)
                writeValue(stream, value.name)
                writeValue(stream, value.value)
            }

            is AudienzzProducerObject -> {
                stream.write(VALUE_PRODUCER_OBJECT.toInt())
                writeValue(stream, value.id)
                writeValue(stream, value.name)
                writeValue(stream, value.domain)
                writeValue(stream, value.getCategories())
            }

            is MinSizePercentage -> {
                stream.write(VALUE_MIN_SIZE_PERCENTAGE.toInt())
                writeValue(stream, value.width)
                writeValue(stream, value.height)
            }

            else -> {
                super.writeValue(stream, value)
            }
        }
    }

    override fun readValueOfType(type: Byte, buffer: ByteBuffer): Any? {
        return when (type) {
            VALUE_INITIALIZATION_STATUS -> {
                val value = readValueOfType(buffer.get(), buffer) as? Int

                when (value) {
                    0 -> InitializationStatus.SUCCESS
                    1 -> InitializationStatus.FAIL
                    else -> throw IllegalArgumentException("Unexpected initialization status value: $value")
                }
            }

            VALUE_AD_SIZE -> {
                val width = readValueOfType(buffer.get(), buffer) as? Int
                val height = readValueOfType(buffer.get(), buffer) as? Int

                if (width != null && height != null) {
                    return AdSize(width, height)
                } else {
                    throw IllegalArgumentException("Missing or unexpected ad size value")
                }
            }

            VALUE_AD_ERROR -> {
                val code = readValueOfType(buffer.get(), buffer) as? Int
                val message = readValueOfType(buffer.get(), buffer) as? String

                if (code != null && message != null) {
                    return AdError(
                        code,
                        message,
                        "Empty domain"
                    )
                } else {
                    throw IllegalArgumentException("Missing or unexpected ad error value")
                }
            }

            VALUE_REWARD_ITEM -> {
                val amount = readValueOfType(buffer.get(), buffer) as Int?
                val rewardItemType = readValueOfType(buffer.get(), buffer) as String?

                if (amount != null && rewardItemType != null) {
                    return RewardAdItem(amount, rewardItemType)
                } else {
                    throw IllegalArgumentException("Missing or unexpected reward item value")
                }
            }

            VALUE_AD_FORMAT -> {
                val value = readValueOfType(buffer.get(), buffer) as Int?

                when (value) {
                    0 -> AdFormat.BANNER
                    1 -> AdFormat.VIDEO
                    2 -> AdFormat.BANNER_AND_VIDEO
                    else -> throw IllegalArgumentException("Missing or unexpected ad format value: $value")
                }
            }

            VALUE_API_PARAMETER -> {
                val value = readValueOfType(buffer.get(), buffer) as Int?

                when (value) {
                    0 -> AudienzzSignals.Api.VPAID_1
                    1 -> AudienzzSignals.Api.VPAID_2
                    2 -> AudienzzSignals.Api.MRAID_1
                    3 -> AudienzzSignals.Api.ORMMA
                    4 -> AudienzzSignals.Api.MRAID_2
                    5 -> AudienzzSignals.Api.MRAID_3
                    6 -> AudienzzSignals.Api.OMID_1
                    else -> throw IllegalArgumentException("Missing or unexpected api parameter value: $value")
                }
            }

            VALUE_PROTOCOL -> {
                val value = readValueOfType(buffer.get(), buffer) as Int?

                when (value) {
                    0 -> AudienzzSignals.Protocols.VAST_1_0
                    1 -> AudienzzSignals.Protocols.VAST_2_0
                    2 -> AudienzzSignals.Protocols.VAST_3_0
                    3 -> AudienzzSignals.Protocols.VAST_1_0_WRAPPER
                    4 -> AudienzzSignals.Protocols.VAST_2_0_WRAPPER
                    5 -> AudienzzSignals.Protocols.VAST_3_0_WRAPPER
                    6 -> AudienzzSignals.Protocols.VAST_4_0
                    7 -> AudienzzSignals.Protocols.VAST_4_0_WRAPPER
                    8 -> AudienzzSignals.Protocols.DAAST_1_0
                    9 -> AudienzzSignals.Protocols.DAAST_1_0_WRAPPER
                    else -> throw IllegalArgumentException("Missing or unexpected protocol value: $value")
                }
            }

            VALUE_PLACEMENT -> {
                val value = readValueOfType(buffer.get(), buffer) as Int?

                when (value) {
                    0 -> AudienzzSignals.Placement.InStream
                    1 -> AudienzzSignals.Placement.InBanner
                    2 -> AudienzzSignals.Placement.InArticle
                    3 -> AudienzzSignals.Placement.InFeed
                    4 -> AudienzzSignals.Placement.Interstitial
                    5 -> AudienzzSignals.Placement.Slider
                    6 -> AudienzzSignals.Placement.Floating
                    else -> throw IllegalArgumentException("Missing or unexpected placement value: $value")
                }
            }

            VALUE_PLAYBACK_METHOD -> {
                val value = readValueOfType(buffer.get(), buffer) as Int?

                when (value) {
                    0 -> AudienzzSignals.PlaybackMethod.AutoPlaySoundOn
                    1 -> AudienzzSignals.PlaybackMethod.AutoPlaySoundOff
                    2 -> AudienzzSignals.PlaybackMethod.ClickToPlay
                    3 -> AudienzzSignals.PlaybackMethod.MouseOver
                    4 -> AudienzzSignals.PlaybackMethod.EnterSoundOn
                    5 -> AudienzzSignals.PlaybackMethod.EnterSoundOff
                    else -> throw IllegalArgumentException("Missing or unexpected playback method value: $value")
                }
            }

            VALUE_VIDEO_BITRATE -> {
                val minBitrate = readValueOfType(buffer.get(), buffer) as Int?
                val maxBitrate = readValueOfType(buffer.get(), buffer) as Int?

                if (minBitrate != null && maxBitrate != null) {
                    return VideoBitrate(minBitrate, maxBitrate)
                } else {
                    throw IllegalArgumentException("Missing or unexpected video bitrate value")
                }
            }

            VALUE_VIDEO_DURATION -> {
                val minDuration = readValueOfType(buffer.get(), buffer) as Int?
                val maxDuration = readValueOfType(buffer.get(), buffer) as Int?

                if (minDuration != null && maxDuration != null) {
                    return VideoDuration(minDuration, maxDuration)
                } else {
                    throw IllegalArgumentException("Missing or unexpected video duration value")
                }
            }

            VALUE_APP_CONTENT -> {
                val contentObject = AudienzzContentObject()
                contentObject.id = readValueOfType(buffer.get(), buffer) as String?
                contentObject.episode = readValueOfType(buffer.get(), buffer) as Int?
                contentObject.title = readValueOfType(buffer.get(), buffer) as String?
                contentObject.series = readValueOfType(buffer.get(), buffer) as String?
                contentObject.season = readValueOfType(buffer.get(), buffer) as String?
                contentObject.artist = readValueOfType(buffer.get(), buffer) as String?
                contentObject.genre = readValueOfType(buffer.get(), buffer) as String?
                contentObject.album = readValueOfType(buffer.get(), buffer) as String?
                contentObject.isrc = readValueOfType(buffer.get(), buffer) as String?
                contentObject.url = readValueOfType(buffer.get(), buffer) as String?

                val categories = (readValueOfType(buffer.get(), buffer) as List<String>?)

                if (categories != null) {
                    contentObject.categories = categories
                }
                contentObject.productionQuality = readValueOfType(buffer.get(), buffer) as Int?
                contentObject.context = readValueOfType(buffer.get(), buffer) as Int?
                contentObject.contentRating = readValueOfType(buffer.get(), buffer) as String?
                contentObject.userRating = readValueOfType(buffer.get(), buffer) as String?
                contentObject.qaMediaRating = readValueOfType(buffer.get(), buffer) as Int?
                contentObject.keywords = readValueOfType(buffer.get(), buffer) as String?
                contentObject.liveStream = readValueOfType(buffer.get(), buffer) as Int?
                contentObject.sourceRelationship = readValueOfType(buffer.get(), buffer) as Int?
                contentObject.length = readValueOfType(buffer.get(), buffer) as Int?
                contentObject.language = readValueOfType(buffer.get(), buffer) as String?
                contentObject.embeddable = readValueOfType(buffer.get(), buffer) as Int?

                val dataList = readValueOfType(buffer.get(), buffer) as List<AudienzzDataObject>?
                if (dataList != null) {
                    contentObject.setDataList(
                        dataList
                    )
                }
                contentObject.producer =
                    readValueOfType(buffer.get(), buffer) as AudienzzProducerObject?

                return contentObject
            }

            VALUE_DATA_OBJECT -> {
                val dataObject = AudienzzDataObject()
                dataObject.id = readValueOfType(buffer.get(), buffer) as String?
                dataObject.name = readValueOfType(buffer.get(), buffer) as String?
                val segments = readValueOfType(
                    buffer.get(),
                    buffer
                ) as List<AudienzzDataObject.AudienzzSegmentObject>?

                if (segments != null) {
                    for (segment in segments) {
                        dataObject.addSegment(segment)
                    }
                }

                return dataObject
            }

            VALUE_DATA_OBJECT_SEGMENT -> {
                val segmentObject = AudienzzDataObject.AudienzzSegmentObject()

                segmentObject.id = readValueOfType(buffer.get(), buffer) as String?
                segmentObject.name = readValueOfType(buffer.get(), buffer) as String?
                segmentObject.value = readValueOfType(buffer.get(), buffer) as String?

                return segmentObject
            }

            VALUE_PRODUCER_OBJECT -> {
                val producerObject = AudienzzProducerObject()
                producerObject.id = readValueOfType(buffer.get(), buffer) as String?
                producerObject.name = readValueOfType(buffer.get(), buffer) as String?
                producerObject.domain = readValueOfType(buffer.get(), buffer) as String?
                val categories = readValueOfType(buffer.get(), buffer) as List<String>?
                if (categories != null) {
                    for (category in categories) {
                        producerObject.addCategory(category)
                    }
                }

                return producerObject
            }

            VALUE_MIN_SIZE_PERCENTAGE -> {
                val width = readValueOfType(buffer.get(), buffer) as Int?
                val height = readValueOfType(buffer.get(), buffer) as Int?

                if (width != null && height != null) {
                    return MinSizePercentage(width, height)
                } else {
                    throw IllegalArgumentException("Missing or unexpected min size percentage value")
                }
            }

            else -> {
                super.readValueOfType(type, buffer)
            }
        }
    }

    companion object {
        private const val VALUE_INITIALIZATION_STATUS: Byte = 128.toByte()
        private const val VALUE_AD_SIZE: Byte = 129.toByte()
        private const val VALUE_AD_ERROR: Byte = 130.toByte()
        private const val VALUE_REWARD_ITEM: Byte = 131.toByte()
        private const val VALUE_AD_FORMAT: Byte = 132.toByte()
        private const val VALUE_API_PARAMETER: Byte = 133.toByte()
        private const val VALUE_PROTOCOL: Byte = 134.toByte()
        private const val VALUE_PLACEMENT: Byte = 135.toByte()
        private const val VALUE_PLAYBACK_METHOD: Byte = 136.toByte()
        private const val VALUE_VIDEO_BITRATE: Byte = 137.toByte()
        private const val VALUE_VIDEO_DURATION: Byte = 138.toByte()
        private const val VALUE_APP_CONTENT: Byte = 139.toByte()
        private const val VALUE_DATA_OBJECT: Byte = 140.toByte()
        private const val VALUE_DATA_OBJECT_SEGMENT: Byte = 141.toByte()
        private const val VALUE_PRODUCER_OBJECT: Byte = 142.toByte()
        private const val VALUE_MIN_SIZE_PERCENTAGE: Byte = 143.toByte()
    }
}
