package com.roommanager.android.ui

import android.app.Activity
import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.roommanager.android.firebase.FirebaseManager
import com.roommanager.android.model.Room
import com.roommanager.android.model.RoomColor
import com.roommanager.android.utils.PreferencesManager
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.SharingStarted
import com.roommanager.android.ui.components.CellStyle

/**
 * ViewModel для управления состоянием комнат и интерфейса
 */
class RoomViewModel(private val context: Context? = null) : ViewModel() {
    
    private val firebaseManager = FirebaseManager.instance
    private val preferencesManager: PreferencesManager? = context?.let { PreferencesManager.getInstance(it) }
    
    // Состояние UI с загрузкой из настроек
    private val _selectedFloor = MutableStateFlow<Int?>(null)
    val selectedFloor: StateFlow<Int?> = _selectedFloor.asStateFlow()
    
    private val _hideWhiteRooms = MutableStateFlow(preferencesManager?.getHideWhiteRooms() ?: false)
    val hideWhiteRooms: StateFlow<Boolean> = _hideWhiteRooms.asStateFlow()
    
    private val _showMarkedOnly = MutableStateFlow(preferencesManager?.getShowMarkedOnly() ?: false)
    val showMarkedOnly: StateFlow<Boolean> = _showMarkedOnly.asStateFlow()
    
    private val _selectedColorFilter = MutableStateFlow(preferencesManager?.getSelectedColorFilter())
    val selectedColorFilter: StateFlow<String?> = _selectedColorFilter.asStateFlow()
    
    private val _cellStyle = MutableStateFlow(preferencesManager?.getCellStyle() ?: CellStyle.FLAT)
    val cellStyle: StateFlow<CellStyle> = _cellStyle.asStateFlow()
    
    // Проброс состояний из FirebaseManager
    val rooms = firebaseManager.rooms
    val isAuthenticated = firebaseManager.isAuthenticated
    val currentUserEmail = firebaseManager.currentUserEmail
    val isSyncing = firebaseManager.isSyncing
    val lastSyncTime = firebaseManager.lastSyncTime
    val error = firebaseManager.error
    
    // Отфильтрованные комнаты с учетом настроек
    val filteredRooms: StateFlow<List<Room>> = combine(
        rooms,
        selectedFloor,
        hideWhiteRooms,
        showMarkedOnly,
        selectedColorFilter
    ) { roomsList, floor, hideWhite, markedOnly, colorFilter ->
        var filtered = roomsList
        
        // Фильтр по этажу
        floor?.let { floorNumber ->
            filtered = filtered.filter { room ->
                room.number.firstOrNull()?.toString()?.toIntOrNull() == floorNumber
            }
        }
        
        // Скрытие белых комнат
        if (hideWhite) {
            filtered = filtered.filter { it.color != RoomColor.WHITE }
        }
        
        // Показать только помеченные
        if (markedOnly) {
            filtered = filtered.filter { it.isMarked }
        }
        
        // Фильтр по цвету
        colorFilter?.let { color ->
            filtered = when (color) {
                "GREEN_BLUE" -> filtered.filter { it.color == RoomColor.GREEN || it.color == RoomColor.BLUE }
                else -> filtered.filter { it.color.toString() == color }
            }
        }
        
        filtered.sortedBy { it.number }
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyList()
    )
    
    // Статистика комнат
    val roomCounts: StateFlow<Map<String, Int>> = combine(
        rooms,
        filteredRooms
    ) { _, filtered -> // allRooms не используется
        val totalCounts = firebaseManager.getRoomCounts()
        val filteredCounts = mapOf(
            "filtered_total" to filtered.size,
            "filtered_none" to filtered.count { it.color == RoomColor.NONE },
            "filtered_red" to filtered.count { it.color == RoomColor.RED },
            "filtered_green" to filtered.count { it.color == RoomColor.GREEN },
            "filtered_purple" to filtered.count { it.color == RoomColor.PURPLE },
            "filtered_blue" to filtered.count { it.color == RoomColor.BLUE },
            "filtered_white" to filtered.count { it.color == RoomColor.WHITE },
            "filtered_marked" to filtered.count { it.isMarked },
            "filtered_deepCleaned" to filtered.count { it.isDeepCleaned }
        )
        totalCounts + filteredCounts
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5000),
        initialValue = emptyMap()
    )
    
    // Доступные этажи
    val availableFloors: StateFlow<List<Int>> = rooms.run {
        combine(this) { roomsList ->
            roomsList[0].mapNotNull { room ->
                room.number.firstOrNull()?.toString()?.toIntOrNull()
            }.distinct().sorted()
        }.stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5000),
            initialValue = emptyList()
        )
    }

    /**
     * 🚀 АВТОМАТИЧЕСКАЯ АВТОРИЗАЦИЯ при запуске приложения
     * Использует встроенные учетные данные axrbarsic@gmail.com
     */
    fun autoSignIn() {
        viewModelScope.launch {
            firebaseManager.autoSignIn()
        }
    }

    /**
     * Подключение к Firebase
     */
    fun connectToFirebase() {
        viewModelScope.launch {
            firebaseManager.signInAnonymously()
        }
    }

    /**
     * Обновление данных без повторной авторизации (для pull-to-refresh)
     */
    fun refresh() {
        // Просто очищаем ошибку - Firebase автоматически обновит данные
        firebaseManager.clearError()
        
        // Если пользователь не аутентифицирован, выполняем подключение
        if (!firebaseManager.isAuthenticated.value) {
            connectToFirebase()
        }
    }

    /**
     * Выбрать этаж для отображения
     */
    fun selectFloor(floor: Int?) {
        _selectedFloor.value = floor
    }

    /**
     * Переключить видимость белых комнат
     */
    fun toggleWhiteRoomsVisibility() {
        val newValue = !_hideWhiteRooms.value
        _hideWhiteRooms.value = newValue
        preferencesManager?.setHideWhiteRooms(newValue)
    }

    /**
     * Переключить показ только помеченных комнат
     */
    fun toggleShowMarkedOnly() {
        val newValue = !_showMarkedOnly.value
        _showMarkedOnly.value = newValue
        preferencesManager?.setShowMarkedOnly(newValue)
    }
    
    /**
     * Переключить стиль ячеек между плоским и классическим
     */
    fun toggleCellStyle() {
        val newStyle = when (_cellStyle.value) {
            CellStyle.FLAT -> CellStyle.CLASSIC
            CellStyle.CLASSIC -> CellStyle.FLAT
        }
        _cellStyle.value = newStyle
        preferencesManager?.setCellStyle(newStyle)
    }

    /**
     * Установить фильтр по цвету (как в iOS)
     */
    fun setColorFilter(color: String?) {
        val newFilter = if (_selectedColorFilter.value == color) null else color
        _selectedColorFilter.value = newFilter
        preferencesManager?.setSelectedColorFilter(newFilter)
    }
    
    /**
     * Фильтрация по фиолетовому цвету
     */
    fun filterByPurple() {
        setColorFilter("PURPLE")
    }
    
    /**
     * Фильтрация по желтому цвету (none)
     */
    fun filterByYellow() {
        setColorFilter("NONE")
    }
    
    /**
     * Фильтрация по красному цвету
     */
    fun filterByRed() {
        setColorFilter("RED")
    }
    
    /**
     * Фильтрация по зеленому+синему цвету (объединенный фильтр)
     */
    fun filterByGreen() {
        // Для зеленого фильтра нужна особая логика в filteredRooms
        _selectedColorFilter.value = if (_selectedColorFilter.value == "GREEN_BLUE") null else "GREEN_BLUE"
    }

    /**
     * Очистить ошибку
     */
    fun clearError() {
        firebaseManager.clearError()
    }

    /**
     * Получить цвет для статуса комнаты
     */
    fun getColorForRoomStatus(status: RoomColor): androidx.compose.ui.graphics.Color {
        return when (status) {
            RoomColor.NONE -> androidx.compose.ui.graphics.Color(0xFFFFEB3B) // Желтый
            RoomColor.RED -> androidx.compose.ui.graphics.Color(0xFFF44336) // Красный
            RoomColor.GREEN -> androidx.compose.ui.graphics.Color(0xFF4CAF50) // Зеленый
            RoomColor.PURPLE -> androidx.compose.ui.graphics.Color(0xFF9C27B0) // Фиолетовый
            RoomColor.BLUE -> androidx.compose.ui.graphics.Color(0xFF2196F3) // Синий
            RoomColor.WHITE -> androidx.compose.ui.graphics.Color(0xFFFFFFFF) // Белый
        }
    }

    /**
     * Получить цвет текста для статуса комнаты
     */
    fun getTextColorForRoomStatus(status: RoomColor): androidx.compose.ui.graphics.Color {
        return when (status) {
            RoomColor.NONE, RoomColor.GREEN, RoomColor.WHITE -> 
                androidx.compose.ui.graphics.Color.Black
            RoomColor.RED, RoomColor.PURPLE, RoomColor.BLUE -> 
                androidx.compose.ui.graphics.Color.White
        }
    }

    /**
     * Получить описание статуса комнаты
     */
    fun getStatusDescription(status: RoomColor): String {
        return when (status) {
            RoomColor.NONE -> "Не убрана"
            RoomColor.RED -> "Грязная / Check out"
            RoomColor.GREEN -> "Убрана"
            RoomColor.PURPLE -> "Доступна с времени"
            RoomColor.BLUE -> "Out of order"
            RoomColor.WHITE -> "Скрыта"
        }
    }

    // MARK: - Google Sign-In

    /**
     * Инициализация Google Sign-In
     */
    fun initializeGoogleSignIn(context: Context) {
        firebaseManager.initializeGoogleSignIn(context)
    }

    /**
     * Получить Intent для Google Sign-In
     */
    fun getGoogleSignInIntent() = firebaseManager.getGoogleSignInClient()?.signInIntent

    /**
     * Обработка результата Google Sign-In
     */
    fun handleGoogleSignInResult(task: com.google.android.gms.tasks.Task<com.google.android.gms.auth.api.signin.GoogleSignInAccount>) {
        viewModelScope.launch {
            firebaseManager.handleGoogleSignInResult(task)
        }
    }

    /**
     * Выход из аккаунта
     */
    fun signOut() {
        viewModelScope.launch {
            firebaseManager.signOut()
        }
    }

    /**
     * Проверка доступности Google Sign-In
     */
    fun isGoogleSignInAvailable(): Boolean {
        return firebaseManager.isGoogleSignInAvailable()
    }
} 