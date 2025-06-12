package com.roommanager.android.model

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentId
import com.google.firebase.firestore.ServerTimestamp
import java.util.*

/**
 * Firebase модель комнаты - для синхронизации с iOS приложением
 * Соответствует структуре FirebaseRoom из Swift приложения
 */
data class FirebaseRoom(
    @DocumentId
    var id: String? = null,
    var number: String = "",
    var color: String = "none",
    var availableTime: String? = null,
    var redTimestamp: Timestamp? = null,
    var greenTimestamp: Timestamp? = null,
    var blueTimestamp: Timestamp? = null,
    var whiteTimestamp: Timestamp? = null,
    var noneTimestamp: Timestamp? = null,
    var isMarked: Boolean = false,
    var isCompletedBefore930: Boolean = false,
    var isDeepCleaned: Boolean = false,
    var localId: String? = null,
    @ServerTimestamp
    var lastModified: Timestamp? = null,
    var deviceId: String = ""
) {
    constructor() : this(null)

    /**
     * Конвертирует Firebase модель в локальную модель Room
     */
    fun toLocalRoom(): Room {
        return Room(
            id = id ?: UUID.randomUUID().toString(),
            number = number,
            color = RoomColor.fromString(color),
            availableTime = availableTime,
            redTimestamp = redTimestamp,
            greenTimestamp = greenTimestamp,
            blueTimestamp = blueTimestamp,
            whiteTimestamp = whiteTimestamp,
            noneTimestamp = noneTimestamp,
            isMarked = isMarked,
            isCompletedBefore930 = isCompletedBefore930,
            isDeepCleaned = isDeepCleaned
        )
    }

    companion object {
        /**
         * Создает Firebase модель из локальной модели Room
         */
        fun fromLocalRoom(room: Room, deviceId: String): FirebaseRoom {
            return FirebaseRoom(
                id = room.id,
                number = room.number,
                color = room.color.value,
                availableTime = room.availableTime,
                redTimestamp = room.redTimestamp,
                greenTimestamp = room.greenTimestamp,
                blueTimestamp = room.blueTimestamp,
                whiteTimestamp = room.whiteTimestamp,
                noneTimestamp = room.noneTimestamp,
                isMarked = room.isMarked,
                isCompletedBefore930 = room.isCompletedBefore930,
                isDeepCleaned = room.isDeepCleaned,
                localId = null,
                lastModified = Timestamp.now(),
                deviceId = deviceId
            )
        }
    }
}

/**
 * Метаданные синхронизации
 */
data class SyncMetadata(
    @DocumentId
    var id: String? = null,
    @ServerTimestamp
    var lastSyncTimestamp: Timestamp? = null,
    var deviceId: String = "",
    var deviceName: String = ""
) {
    constructor() : this(null)
} 