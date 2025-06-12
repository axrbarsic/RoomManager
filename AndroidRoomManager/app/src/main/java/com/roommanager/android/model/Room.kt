package com.roommanager.android.model

import com.google.firebase.Timestamp
import com.google.firebase.firestore.DocumentId
import java.util.*

/**
 * Модель комнаты - аналог iOS структуры Room
 */
data class Room(
    @DocumentId
    var id: String = UUID.randomUUID().toString(),
    var number: String = "",
    var color: RoomColor = RoomColor.NONE,
    var availableTime: String? = null,
    var redTimestamp: Timestamp? = null,
    var greenTimestamp: Timestamp? = null,
    var blueTimestamp: Timestamp? = null,
    var whiteTimestamp: Timestamp? = null,
    var noneTimestamp: Timestamp? = null,
    var isMarked: Boolean = false,
    var isCompletedBefore930: Boolean = false,
    var isDeepCleaned: Boolean = false
) {
    constructor() : this(UUID.randomUUID().toString())
}

/**
 * Статусы комнат - аналог iOS enum RoomColor
 */
enum class RoomColor(val value: String) {
    NONE("none"),           // Желтый - не убрана
    RED("red"),             // Красный - грязная/check out
    GREEN("green"),         // Зеленый - убрана
    PURPLE("purple"),       // Фиолетовый - доступна с времени
    BLUE("blue"),           // Синий - out of order
    WHITE("white");         // Белый - скрыта

    companion object {
        fun fromString(value: String): RoomColor {
            return values().find { it.value == value } ?: NONE
        }
    }
} 