package com.roommanager.android.firebase

import android.app.Activity
import android.content.Context
import android.os.Build
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInClient
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.ApiException
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.GoogleAuthProvider
import com.google.firebase.firestore.DocumentChange
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.ListenerRegistration
import com.google.firebase.firestore.MetadataChanges
import com.roommanager.android.R
import com.roommanager.android.model.FirebaseRoom
import com.roommanager.android.model.Room
import com.roommanager.android.model.SyncMetadata
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await
import java.util.*

/**
 * Firebase менеджер для синхронизации с iOS приложением RoomManager
 * Обеспечивает real-time синхронизацию комнат между устройствами
 * ВСТРОЕННАЯ АВТОРИЗАЦИЯ: автоматически использует аккаунт axrbarsic@gmail.com
 */
class FirebaseManager private constructor() {
    
    companion object {
        val instance: FirebaseManager by lazy { FirebaseManager() }
        private const val TAG = "FirebaseManager"
        private const val USERS_COLLECTION = "users"
        private const val ROOMS_COLLECTION = "rooms"
        private const val SYNC_METADATA_COLLECTION = "sync_metadata"
        
        // 🔑 ВСТРОЕННЫЕ УЧЕТНЫЕ ДАННЫЕ - axrbarsic@gmail.com
        private const val HARDCODED_USER_ID = "38Pv7JGnFnT8IpVncfGVkYuPzLp2"
        private const val HARDCODED_USER_EMAIL = "axrbarsic@gmail.com"
    }

    private val db = FirebaseFirestore.getInstance()
    private val auth = FirebaseAuth.getInstance()
    
    // Google Sign-In клиент (оставляем для совместимости)
    private var googleSignInClient: GoogleSignInClient? = null
    
    // Уникальный ID устройства
    private val deviceId = "${Build.MODEL}_${UUID.randomUUID()}"
    private val deviceName = "${Build.MANUFACTURER} ${Build.MODEL}"
    
    // Listener для real-time обновлений
    private var roomsListener: ListenerRegistration? = null
    
    // StateFlows для реактивного UI
    private val _rooms = MutableStateFlow<List<Room>>(emptyList())
    val rooms: StateFlow<List<Room>> = _rooms.asStateFlow()
    
    private val _isAuthenticated = MutableStateFlow(false)
    val isAuthenticated: StateFlow<Boolean> = _isAuthenticated.asStateFlow()
    
    private val _currentUserEmail = MutableStateFlow<String?>(null)
    val currentUserEmail: StateFlow<String?> = _currentUserEmail.asStateFlow()
    
    private val _isSyncing = MutableStateFlow(false)
    val isSyncing: StateFlow<Boolean> = _isSyncing.asStateFlow()
    
    private val _lastSyncTime = MutableStateFlow<Timestamp?>(null)
    val lastSyncTime: StateFlow<Timestamp?> = _lastSyncTime.asStateFlow()
    
    private val _error = MutableStateFlow<String?>(null)
    val error: StateFlow<String?> = _error.asStateFlow()

    init {
        // 🚀 АВТОМАТИЧЕСКАЯ АВТОРИЗАЦИЯ ПРИ ИНИЦИАЛИЗАЦИИ
        Log.d(TAG, "🔧 Инициализация FirebaseManager с встроенной авторизацией")
        
        // Проверяем текущую аутентификацию
        auth.addAuthStateListener { firebaseAuth ->
            val user = firebaseAuth.currentUser
            
            if (user != null) {
                Log.d(TAG, "✅ Пользователь уже аутентифицирован: ${user.uid}, email: ${user.email}")
                _isAuthenticated.value = true
                _currentUserEmail.value = HARDCODED_USER_EMAIL // Всегда показываем встроенный email
                
                // Начинаем слушать комнаты для встроенного пользователя
                startListeningForRooms(HARDCODED_USER_ID)
            } else {
                Log.d(TAG, "❌ Пользователь не аутентифицирован, начинаем автоматическую авторизацию")
                _isAuthenticated.value = false
                _currentUserEmail.value = null
                stopListeningForRooms()
            }
        }
    }

    /**
     * 🔑 АВТОМАТИЧЕСКАЯ АВТОРИЗАЦИЯ С ВСТРОЕННЫМ АККАУНТОМ
     * Использует предустановленные учетные данные axrbarsic@gmail.com
     */
    suspend fun autoSignIn(): Boolean {
        return try {
            _isSyncing.value = true
            _error.value = null
            
            Log.d(TAG, "🚀 Начинаем автоматическую авторизацию для $HARDCODED_USER_EMAIL")
            
            // Если уже авторизован под нужным пользователем, ничего не делаем
            val currentUser = auth.currentUser
            if (currentUser != null) {
                Log.d(TAG, "✅ Пользователь уже авторизован: ${currentUser.uid}")
                _isAuthenticated.value = true
                _currentUserEmail.value = HARDCODED_USER_EMAIL
                startListeningForRooms(HARDCODED_USER_ID)
                return true
            }
          
            Log.d(TAG, "Пользователь не авторизован, выполняем анонимную авторизацию...")
            
            // Выполняем анонимную авторизацию и сразу связываем с нужным пользователем
            val result = auth.signInAnonymously().await()
            if (result.user != null) {
                Log.d(TAG, "✅ Анонимная авторизация успешна: ${result.user!!.uid}")
                Log.d(TAG, "✅ Используем данные пользователя: $HARDCODED_USER_EMAIL")
                _isAuthenticated.value = true
                _currentUserEmail.value = HARDCODED_USER_EMAIL
                
                // Начинаем слушать комнаты для встроенного пользователя
                startListeningForRooms(HARDCODED_USER_ID)
                return true
            }
            
            Log.e(TAG, "❌ Анонимная авторизация не удалась")
            false
        } catch (e: Exception) {
            Log.e(TAG, "❌ Ошибка автоматической авторизации", e)
            _error.value = "Ошибка автоматической авторизации: ${e.message}"
            false
        } finally {
            _isSyncing.value = false
        }
    }

    /**
     * Анонимная аутентификация (оставляем для совместимости)
     */
    suspend fun signInAnonymously(): Boolean {
        return autoSignIn()
    }

    /**
     * Запускает слушание изменений комнат в реальном времени
     */
    private fun startListeningForRooms(userId: String) {
        Log.d(TAG, "Начинаем слушать изменения комнат для пользователя: $userId")
        
        stopListeningForRooms()
        
        // Пробуем сначала корневую коллекцию, потом пользовательскую
        startListeningToRootCollection(userId)
    }
    
    /**
     * Попытка подключения к корневой коллекции комнат
     */
    private fun startListeningToRootCollection(fallbackUserId: String) {
        Log.d(TAG, "Пробуем подключиться к корневой коллекции 'rooms'")
        
        roomsListener = db.collection("rooms")
            .addSnapshotListener(MetadataChanges.INCLUDE) { snapshot, error ->
                if (error != null) {
                    Log.w(TAG, "Ошибка корневой коллекции, пробуем пользовательскую: ${error.message}")
                    // Переключаемся на пользовательскую коллекцию
                    startListeningToUserCollection(fallbackUserId)
                    return@addSnapshotListener
                }
                
                if (snapshot != null && !snapshot.isEmpty) {
                    Log.d(TAG, "Успешно подключились к корневой коллекции, документов: ${snapshot.size()}")
                    processRoomsSnapshot(snapshot)
                } else {
                    Log.d(TAG, "Корневая коллекция пуста, пробуем пользовательскую")
                    startListeningToUserCollection(fallbackUserId)
                }
            }
    }
    
    /**
     * Подключение к коллекции пользователя
     */
    private fun startListeningToUserCollection(userId: String) {
        Log.d(TAG, "Подключаемся к пользовательской коллекции: users/$userId/rooms")
        
        roomsListener?.remove() // Отключаем предыдущий listener
        
        roomsListener = db.collection(USERS_COLLECTION)
            .document(userId)
            .collection(ROOMS_COLLECTION)
            .addSnapshotListener(MetadataChanges.INCLUDE) { snapshot, error ->
                if (error != null) {
                    Log.e(TAG, "Ошибка при получении комнат из пользовательской коллекции", error)
                    _error.value = "Ошибка синхронизации: ${error.message}"
                    return@addSnapshotListener
                }
                
                if (snapshot != null) {
                    Log.d(TAG, "Получены данные из пользовательской коллекции, документов: ${snapshot.size()}")
                    processRoomsSnapshot(snapshot)
                } else {
                    Log.w(TAG, "Пустой snapshot из пользовательской коллекции")
                }
            }
    }
    
    /**
     * Обработка snapshot данных комнат (общий метод)
     */
    private fun processRoomsSnapshot(snapshot: com.google.firebase.firestore.QuerySnapshot) {
        try {
            // Обрабатываем изменения для лучшей отладки
            if (!snapshot.metadata.isFromCache) {
                Log.d(TAG, "Получены изменения комнат с сервера (${snapshot.documentChanges.size} изменений)")
                
                // ИСПРАВЛЕНО: Обрабатываем каждое изменение по типу
                val currentRooms = _rooms.value.toMutableList()
                
                snapshot.documentChanges.forEach { change ->
                    Log.d(TAG, "Изменение: тип=${change.type}, документ=${change.document.id}")
                    
                    when (change.type) {
                        DocumentChange.Type.ADDED, DocumentChange.Type.MODIFIED -> {
                            try {
                                val firebaseRoom = change.document.toObject(FirebaseRoom::class.java)
                                Log.d(TAG, "  Комната: ${firebaseRoom.number}, цвет=${firebaseRoom.color}, isMarked=${firebaseRoom.isMarked}, isDeepCleaned=${firebaseRoom.isDeepCleaned}, isCompletedBefore930=${firebaseRoom.isCompletedBefore930}")
                                
                                val localRoom = firebaseRoom.toLocalRoom()
                                Log.d(TAG, "Обработана комната: ${localRoom.number}, isMarked=${localRoom.isMarked}, isDeepCleaned=${localRoom.isDeepCleaned}, isCompletedBefore930=${localRoom.isCompletedBefore930}")
                                
                                // Удаляем старую версию если есть
                                val existingIndex = currentRooms.indexOfFirst { it.id == localRoom.id }
                                if (existingIndex >= 0) {
                                    currentRooms[existingIndex] = localRoom
                                    Log.d(TAG, "  Обновлена существующая комната ${localRoom.number}")
                                } else {
                                    currentRooms.add(localRoom)
                                    Log.d(TAG, "  Добавлена новая комната ${localRoom.number}")
                                }
                            } catch (e: Exception) {
                                Log.e(TAG, "Ошибка при парсинге комнаты ${change.document.id}", e)
                            }
                        }
                        
                        DocumentChange.Type.REMOVED -> {
                            val roomId = change.document.id
                            Log.d(TAG, "  🗑️ УДАЛЕНИЕ комнаты с ID: ${roomId}")
                            
                            // Находим комнату по ID документа (UUID строка) 
                            val roomToRemove = currentRooms.find { room ->
                                room.id.toString() == roomId
                            }
                            
                            if (roomToRemove != null) {
                                currentRooms.remove(roomToRemove)
                                Log.d(TAG, "  ✅ Удалена комната ${roomToRemove.number} из списка")
                            } else {
                                Log.w(TAG, "  ⚠️ Комната для удаления не найдена в списке")
                                // Дополнительная отладка
                                Log.d(TAG, "  Ищем среди ${currentRooms.size} комнат:")
                                currentRooms.take(5).forEach { room ->
                                    Log.d(TAG, "    - ${room.number} (ID: ${room.id})")
                                }
                            }
                        }
                    }
                }
                
                // Сортируем и обновляем список
                val sortedRooms = currentRooms.sortedBy { it.number }
                _rooms.value = sortedRooms
                _lastSyncTime.value = Timestamp.now()
                _error.value = null
                
                Log.d(TAG, "Обновлен список комнат: ${sortedRooms.size} комнат")
                
                // Подробный лог первых нескольких комнат
                sortedRooms.take(3).forEach { room ->
                    Log.d(TAG, "Комната ${room.number}: цвет=${room.color}, isMarked=${room.isMarked}, isDeepCleaned=${room.isDeepCleaned}, isCompletedBefore930=${room.isCompletedBefore930}")
                }
            } else {
                Log.d(TAG, "Данные из кэша, пропускаем обработку")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Ошибка при обработке данных комнат", e)
            _error.value = "Ошибка обработки данных: ${e.message}"
        }
    }

    /**
     * Останавливает слушание изменений комнат
     */
    private fun stopListeningForRooms() {
        roomsListener?.remove()
        roomsListener = null
        _rooms.value = emptyList()
    }

    /**
     * Обновляет метаданные синхронизации
     */
    private suspend fun updateSyncMetadata(userId: String) {
        try {
            val metadata = SyncMetadata(
                id = deviceId,
                lastSyncTimestamp = Timestamp.now(),
                deviceId = deviceId,
                deviceName = deviceName
            )
            
            db.collection(USERS_COLLECTION)
                .document(userId)
                .collection(SYNC_METADATA_COLLECTION)
                .document(deviceId)
                .set(metadata)
                .await()
                
            Log.d(TAG, "Метаданные синхронизации обновлены")
        } catch (e: Exception) {
            Log.e(TAG, "Ошибка при обновлении метаданных синхронизации", e)
        }
    }

    /**
     * Получает количество комнат по статусам
     */
    fun getRoomCounts(): Map<String, Int> {
        val currentRooms = _rooms.value
        return mapOf(
            "total" to currentRooms.size,
            "none" to currentRooms.count { it.color == com.roommanager.android.model.RoomColor.NONE },
            "red" to currentRooms.count { it.color == com.roommanager.android.model.RoomColor.RED },
            "green" to currentRooms.count { it.color == com.roommanager.android.model.RoomColor.GREEN },
            "purple" to currentRooms.count { it.color == com.roommanager.android.model.RoomColor.PURPLE },
            "blue" to currentRooms.count { it.color == com.roommanager.android.model.RoomColor.BLUE },
            "white" to currentRooms.count { it.color == com.roommanager.android.model.RoomColor.WHITE },
            "marked" to currentRooms.count { it.isMarked },
            "deepCleaned" to currentRooms.count { it.isDeepCleaned }
        )
    }

    /**
     * Очищает ошибку
     */
    fun clearError() {
        _error.value = null
    }

    /**
     * Получить комнаты для конкретного этажа
     */
    fun getRoomsForFloor(floor: Int): List<Room> {
        return _rooms.value.filter { room ->
            room.number.firstOrNull()?.toString()?.toIntOrNull() == floor
        }.sortedBy { it.number }
    }

    /**
     * Получить список всех этажей
     */
    fun getAvailableFloors(): List<Int> {
        return _rooms.value
            .mapNotNull { room ->
                room.number.firstOrNull()?.toString()?.toIntOrNull()
            }
            .distinct()
            .sorted()
    }

    // MARK: - Google Sign-In

    /**
     * Инициализация Google Sign-In клиента
     */
    fun initializeGoogleSignIn(context: Context) {
        try {
            val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
                .requestIdToken(context.getString(R.string.default_web_client_id))
                .requestEmail()
                .build()

            googleSignInClient = GoogleSignIn.getClient(context, gso)
            Log.d(TAG, "Google Sign-In клиент инициализирован")
        } catch (e: Exception) {
            Log.e(TAG, "Ошибка инициализации Google Sign-In", e)
            _error.value = "Ошибка инициализации Google Sign-In: ${e.message}"
        }
    }

    /**
     * Получить Google Sign-In клиент для запуска авторизации
     */
    fun getGoogleSignInClient(): GoogleSignInClient? = googleSignInClient

    /**
     * Авторизация через Google аккаунт
     */
    suspend fun signInWithGoogle(idToken: String): Boolean {
        return try {
            _isSyncing.value = true
            _error.value = null

            val credential = GoogleAuthProvider.getCredential(idToken, null)
            val result = auth.signInWithCredential(credential).await()
            val success = result.user != null

            if (success) {
                Log.d(TAG, "Успешная авторизация через Google: ${result.user?.email}")
                _isAuthenticated.value = true
                _currentUserEmail.value = result.user?.email
            }

            success
        } catch (e: Exception) {
            Log.e(TAG, "Ошибка Google Sign-In", e)
            _error.value = "Ошибка входа через Google: ${e.message}"
            false
        } finally {
            _isSyncing.value = false
        }
    }

    /**
     * Обработка результата Google Sign-In
     */
    suspend fun handleGoogleSignInResult(task: com.google.android.gms.tasks.Task<com.google.android.gms.auth.api.signin.GoogleSignInAccount>): Boolean {
        return try {
            val account = task.getResult(ApiException::class.java)
            val idToken = account.idToken

            if (idToken != null) {
                signInWithGoogle(idToken)
            } else {
                Log.e(TAG, "ID Token равен null")
                _error.value = "Ошибка получения токена от Google"
                false
            }
        } catch (e: ApiException) {
            Log.e(TAG, "Google Sign-In ошибка", e)
            _error.value = "Ошибка Google Sign-In: ${e.message}"
            false
        }
    }

    /**
     * Выход из аккаунта
     */
    suspend fun signOut() {
        try {
            auth.signOut()
            googleSignInClient?.signOut()?.await()
            
            _isAuthenticated.value = false
            _currentUserEmail.value = null
            _rooms.value = emptyList()
            
            Log.d(TAG, "Успешный выход из аккаунта")
        } catch (e: Exception) {
            Log.e(TAG, "Ошибка выхода", e)
            _error.value = "Ошибка выхода: ${e.message}"
        }
    }

    /**
     * Проверка доступности Google Sign-In
     */
    fun isGoogleSignInAvailable(): Boolean {
        return googleSignInClient != null
    }
} 