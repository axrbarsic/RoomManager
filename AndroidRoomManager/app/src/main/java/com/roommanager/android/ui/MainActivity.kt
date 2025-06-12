package com.roommanager.android.ui

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
// Убрано - ActivityResultContracts больше не нужен
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.lifecycle.ViewModelProvider
import androidx.activity.viewModels
import com.google.accompanist.swiperefresh.SwipeRefresh
import com.google.accompanist.swiperefresh.rememberSwipeRefreshState
import com.google.accompanist.systemuicontroller.rememberSystemUiController
// Убрано - Google Sign-In imports больше не нужны
import com.roommanager.android.model.Room
import com.roommanager.android.ui.components.RoomCell
import com.roommanager.android.ui.components.CellStyle
import com.roommanager.android.ui.components.LanguageSelectionDialog
import com.roommanager.android.ui.theme.RoomManagerTheme
import com.roommanager.android.utils.*
import com.roommanager.android.R
import android.content.Context

/**
 * Главная активность приложения
 */
class MainActivity : ComponentActivity() {
    
    private lateinit var viewModel: RoomViewModel
    
    // Убрано - ActivityResultLauncher больше не нужен с встроенной авторизацией
    
    override fun attachBaseContext(newBase: Context?) {
        super.attachBaseContext(LocaleHelper.wrapContext(newBase ?: this))
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // Инициализируем ViewModel с контекстом для сохранения настроек
        val factory = RoomViewModelFactory(this)
        viewModel = ViewModelProvider(this, factory)[RoomViewModel::class.java]
        
        // 🚀 АВТОМАТИЧЕСКАЯ АВТОРИЗАЦИЯ ПРИ ЗАПУСКЕ
        viewModel.autoSignIn()
        
        setContent {
            RoomManagerTheme {
                // Устанавливаем темную тему для системных баров
                val systemUiController = rememberSystemUiController()
                
                SideEffect {
                    systemUiController.setSystemBarsColor(
                        color = Color.Black,
                        darkIcons = false
                    )
                }
                
                RoomManagerApp(
                    viewModel = viewModel
                )
            }
        }
    }
    
    // Убрано - встроенная авторизация не требует Google Sign-In
    // private fun startGoogleSignIn() { ... }
}

/**
 * Главный компонент приложения
 * ВСТРОЕННАЯ АВТОРИЗАЦИЯ: автоматически работает с аккаунтом axrbarsic@gmail.com
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RoomManagerApp(viewModel: RoomViewModel = viewModel()) {
    // Состояния из ViewModel
    val rooms by viewModel.filteredRooms.collectAsState()
    val isAuthenticated by viewModel.isAuthenticated.collectAsState()
    val currentUserEmail by viewModel.currentUserEmail.collectAsState()
    val isSyncing by viewModel.isSyncing.collectAsState()
    val error by viewModel.error.collectAsState()
    val roomCounts by viewModel.roomCounts.collectAsState()
    val hideWhiteRooms by viewModel.hideWhiteRooms.collectAsState()
    val selectedColorFilter by viewModel.selectedColorFilter.collectAsState()
    val cellStyle by viewModel.cellStyle.collectAsState()
    
    // Локальное состояние UI
    var showBottomSheet by remember { mutableStateOf(false) }
    var showLanguageDialog by remember { mutableStateOf(false) }
    val context = LocalContext.current
    
    // Функция смены языка
    val changeLanguage = { languageCode: String ->
        LocaleHelper.setLanguage(context, languageCode)
        // Перезапускаем активность для применения нового языка
        (context as MainActivity).recreate()
    }
    
    // Обработка ошибок
    error?.let { errorMessage ->
        LaunchedEffect(errorMessage) {
            // Показываем снэкбар с ошибкой
            // TODO: Добавить SnackbarHost
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    // iOS-стиль верхнего меню с цветными счетчиками - АДАПТИВНО
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.SpaceBetween
                    ) {
                        // Левая часть: общий счетчик + цветные счетчики - АДАПТИВНО
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            modifier = Modifier.weight(1f) // Заполняет доступное пространство
                        ) {
                            // Общий счетчик (всего/невыполненных) - АДАПТИВНЫЙ РАЗМЕР
                            val totalRooms = roomCounts["total"] ?: 0
                            val unfinishedRooms = (roomCounts["none"] ?: 0) + (roomCounts["red"] ?: 0)
                            Text(
                                text = "$totalRooms/$unfinishedRooms",
                                color = Color.White,
                                fontSize = ResponsiveFontSizes.normal(), // Адаптивный размер
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier
                                    .background(
                                        Color.Black.copy(alpha = 0.7f),
                                        RoundedCornerShape(responsiveDp(6f))
                                    )
                                    .padding(horizontal = responsiveSpacing(), vertical = responsiveDp(2f))
                                    .widthIn(min = responsiveDp(40f)) // Адаптивная минимальная ширина
                            )
                            
                            // Цветные счетчики - АДАПТИВНЫЕ
                            ColorCounter(
                                count = roomCounts["purple"] ?: 0,
                                color = Color(0xFF9C27B0),
                                onClick = { viewModel.filterByPurple() },
                                selectedColorFilter = selectedColorFilter,
                                isCompact = true
                            )
                            ColorCounter(
                                count = roomCounts["none"] ?: 0,
                                color = Color(0xFFFFEB3B),
                                onClick = { viewModel.filterByYellow() },
                                selectedColorFilter = selectedColorFilter,
                                isCompact = true
                            )
                            ColorCounter(
                                count = roomCounts["red"] ?: 0,
                                color = Color(0xFFF44336),
                                onClick = { viewModel.filterByRed() },
                                selectedColorFilter = selectedColorFilter,
                                isCompact = true
                            )
                            // Зеленый счетчик объединяет зеленые И синие комнаты
                            ColorCounter(
                                count = (roomCounts["green"] ?: 0) + (roomCounts["blue"] ?: 0),
                                color = Color(0xFF4CAF50),
                                onClick = { viewModel.filterByGreen() },
                                selectedColorFilter = selectedColorFilter,
                                isCompact = true
                            )
                        }
                        
                        // Правая часть: кнопки как в iOS - АДАПТИВНО
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(2.dp) // Уменьшен отступ
                        ) {
                            // Кнопка настроек - АДАПТИВНАЯ
                            IconButton(
                                onClick = { showBottomSheet = true },
                                modifier = Modifier.size(responsiveDp(28f)) // Адаптивный размер
                            ) {
                                Icon(
                                    Icons.Default.Settings,
                                    contentDescription = "Настройки",
                                    tint = Color.White,
                                    modifier = Modifier.size(responsiveDp(18f)) // Адаптивный размер
                                )
                            }
                            
                            // Индикатор синхронизации/подключения - АДАПТИВНЫЙ
                            if (isSyncing) {
                                CircularProgressIndicator(
                                    modifier = Modifier.size(responsiveDp(20f)), // Адаптивный размер
                                    color = Color.Yellow,
                                    strokeWidth = responsiveDp(2.5f)
                                )
                            } else {
                                Icon(
                                    imageVector = if (isAuthenticated) Icons.Default.CheckCircle else Icons.Default.Error,
                                    contentDescription = if (isAuthenticated) "Подключено" else "Не подключено",
                                    tint = if (isAuthenticated) Color.Green else Color.Red,
                                    modifier = Modifier.size(responsiveDp(20f)) // Адаптивный размер
                                )
                            }
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Black
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black)
                .padding(paddingValues)
        ) {
            // Основной контент - всегда показываем интерфейс комнат
            Box(modifier = Modifier.fillMaxSize()) {
                if (rooms.isEmpty() && !isSyncing && isAuthenticated) {
                    // Пустое состояние (только если авторизован, но нет комнат)
                    EmptyState()
                } else if (!isAuthenticated && !isSyncing) {
                    // Экран загрузки при авторизации
                    LoadingScreen()
                } else {
                    // Основной интерфейс - 5 колонок этажей с pull-to-refresh
                    val swipeRefreshState = rememberSwipeRefreshState(isSyncing)
                    
                    SwipeRefresh(
                        state = swipeRefreshState,
                        onRefresh = { viewModel.refresh() }
                    ) {
                        LazyColumn(
                            modifier = Modifier
                                .fillMaxSize()
                                .padding(vertical = responsiveSmallSpacing()), // Адаптивные отступы
                            verticalArrangement = Arrangement.Top // Убираем отступы между строками
                        ) {
                            // Группируем комнаты по строкам, на каждой строке 5 этажей
                            val roomsByFloor = (1..5).associateWith { floor ->
                                rooms.filter { room ->
                                    room.number.firstOrNull()?.toString()?.toIntOrNull() == floor
                                }.sortedBy { it.number }
                            }
                            
                            // Находим максимальное количество комнат на этаже
                            val maxRoomsPerFloor = roomsByFloor.values.maxOfOrNull { it.size } ?: 0
                            
                            // Заголовки этажей - БЕЗ ОТСТУПОВ
                            item {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceEvenly // Равномерное распределение без отступов
                                ) {
                                    for (floor in 1..5) {
                                        Card(
                                            modifier = Modifier.weight(1f), // Автоматическое распределение
                                            colors = CardDefaults.cardColors(
                                                containerColor = Color(0xFF1E1E1E)
                                            ),
                                            shape = RoundedCornerShape(responsiveDp(6f)) // Адаптивное скругление
                                        ) {
                                            Text(
                                                text = floor.toString(),
                                                color = Color.White,
                                                fontSize = ResponsiveFontSizes.medium(), // Адаптивный размер
                                                fontWeight = FontWeight.Bold,
                                                textAlign = TextAlign.Center,
                                                modifier = Modifier
                                                    .fillMaxWidth()
                                                    .padding(responsiveDp(6f)) // Адаптивные отступы
                                            )
                                        }
                                    }
                                }
                            }
                            
                            // Строки с комнатами
                            items(maxRoomsPerFloor) { rowIndex ->
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.SpaceEvenly // Убираем отступы между ячейками
                                ) {
                                    for (floor in 1..5) {
                                        val floorRooms = roomsByFloor[floor] ?: emptyList()
                                        val room = floorRooms.getOrNull(rowIndex)
                                        
                                        Box(modifier = Modifier.weight(1f)) {
                                            if (room != null) {
                                                RoomCell(
                                                    room = room,
                                                    cellStyle = cellStyle, // Динамический стиль из ViewModel
                                                    onClick = { /* TODO: Добавить детальный просмотр */ }
                                                )
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Bottom Sheet с настройками
    if (showBottomSheet) {
        SettingsBottomSheet(
            currentUserEmail = currentUserEmail,
            hideWhiteRooms = hideWhiteRooms,
            cellStyle = cellStyle,
            onToggleWhiteRooms = { viewModel.toggleWhiteRoomsVisibility() },
            onToggleCellStyle = { viewModel.toggleCellStyle() },
            onSignOut = { /* Встроенная авторизация - нет выхода */ },
            onLanguageClick = { showLanguageDialog = true },
            onDismiss = { showBottomSheet = false }
        )
    }
    
    // Диалог выбора языка
    if (showLanguageDialog) {
        LanguageSelectionDialog(
            onLanguageSelected = changeLanguage,
            onDismiss = { showLanguageDialog = false }
        )
    }
}

// Убрано - ConnectionScreen больше не нужен с встроенной авторизацией

/**
 * Экран загрузки при авторизации
 */
@Composable
fun LoadingScreen() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        CircularProgressIndicator(
            modifier = Modifier.size(60.dp),
            strokeWidth = 4.dp,
            color = Color.White
        )
        
        Spacer(modifier = Modifier.height(24.dp))
        
        Text(
            text = stringResource(R.string.connecting_to_server),
            color = Color.White,
            fontSize = 18.sp,
            fontWeight = FontWeight.Medium
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = stringResource(R.string.syncing_with_account),
            color = Color.Gray,
            fontSize = 14.sp,
            textAlign = TextAlign.Center
        )
    }
}

/**
 * Пустое состояние
 */
@Composable
fun EmptyState() {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center
    ) {
        Icon(
            Icons.Default.Hotel,
            contentDescription = null,
            modifier = Modifier.size(80.dp),
            tint = Color.Gray
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Text(
            text = stringResource(R.string.no_rooms_data),
            color = Color.White,
            fontSize = 20.sp,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(8.dp))
        
        Text(
            text = stringResource(R.string.add_rooms_instruction),
            color = Color.Gray,
            textAlign = TextAlign.Center
        )
    }
}

/**
 * Bottom Sheet с настройками
 * ВСТРОЕННАЯ АВТОРИЗАЦИЯ: показывает информацию о пользователе и настройки фильтрации
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsBottomSheet(
    currentUserEmail: String?, // Не используется но оставляем для совместимости
    hideWhiteRooms: Boolean,
    cellStyle: CellStyle,
    onToggleWhiteRooms: () -> Unit,
    onToggleCellStyle: () -> Unit,
    onSignOut: () -> Unit, // Не используется но оставляем для совместимости  
    onLanguageClick: () -> Unit, // Новый параметр для языкового диалога
    onDismiss: () -> Unit
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF1E1E1E)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            Text(
                text = stringResource(R.string.information),
                color = Color.White,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(bottom = 16.dp)
            )
            
            // Информация о встроенном пользователе
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFF2E2E2E)
                )
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(bottom = 8.dp)
                    ) {
                        Icon(
                            Icons.Default.AccountCircle,
                            contentDescription = null,
                            tint = Color(0xFF4CAF50),
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = stringResource(R.string.account),
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    
                    Text(
                        text = stringResource(R.string.user_email),
                        color = Color(0xFF4CAF50),
                        fontSize = 14.sp,
                        fontWeight = FontWeight.Medium
                    )
                    Text(
                        text = stringResource(R.string.built_in_auth),
                        color = Color.Gray,
                        fontSize = 12.sp
                    )
                }
            }
            
            // Информация о синхронизации
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFF2E2E2E)
                )
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(bottom = 8.dp)
                    ) {
                        Icon(
                            Icons.Default.Sync,
                            contentDescription = null,
                            tint = Color(0xFF2196F3),
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = stringResource(R.string.synchronization),
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    
                    Text(
                        text = stringResource(R.string.auto_sync_ios),
                        color = Color(0xFF2196F3),
                        fontSize = 14.sp
                    )
                    Text(
                        text = stringResource(R.string.realtime_updates),
                        color = Color.Gray,
                        fontSize = 12.sp
                    )
                }
            }
            
            // Настройки отображения
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp),
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFF2E2E2E)
                )
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(bottom = 12.dp)
                    ) {
                        Icon(
                            Icons.Default.FilterList,
                            contentDescription = null,
                            tint = Color(0xFFFF9800),
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = stringResource(R.string.display_settings),
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    
                    // Переключатель для скрытия белых комнат
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = stringResource(R.string.hide_white_rooms),
                                color = Color.White,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = if (hideWhiteRooms) stringResource(R.string.hidden) else stringResource(R.string.shown),
                                color = Color.Gray,
                                fontSize = 12.sp
                            )
                        }
                        
                        Switch(
                            checked = hideWhiteRooms,
                            onCheckedChange = { onToggleWhiteRooms() },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = Color.White,
                                checkedTrackColor = Color(0xFF4CAF50),
                                uncheckedThumbColor = Color.Gray,
                                uncheckedTrackColor = Color(0xFF424242)
                            )
                        )
                    }
                    
                    Spacer(modifier = Modifier.height(12.dp))
                    
                    // Переключатель стиля ячеек
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = stringResource(R.string.cell_style),
                                color = Color.White,
                                fontSize = 14.sp,
                                fontWeight = FontWeight.Medium
                            )
                            Text(
                                text = when (cellStyle) {
                                    CellStyle.FLAT -> stringResource(R.string.style_flat)
                                    CellStyle.CLASSIC -> stringResource(R.string.style_classic)
                                },
                                color = Color.Gray,
                                fontSize = 12.sp
                            )
                        }
                        
                        Switch(
                            checked = cellStyle == CellStyle.CLASSIC,
                            onCheckedChange = { onToggleCellStyle() },
                            colors = SwitchDefaults.colors(
                                checkedThumbColor = Color.White,
                                checkedTrackColor = Color(0xFF9C27B0),
                                uncheckedThumbColor = Color.Gray,
                                uncheckedTrackColor = Color(0xFF424242)
                            )
                        )
                    }
                }
            }
            
            // Настройки языка
            Card(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 16.dp)
                    .clickable { onLanguageClick() },
                colors = CardDefaults.cardColors(
                    containerColor = Color(0xFF2E2E2E)
                )
            ) {
                Column(
                    modifier = Modifier.padding(16.dp)
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.padding(bottom = 8.dp)
                    ) {
                        Icon(
                            Icons.Default.Language,
                            contentDescription = null,
                            tint = Color(0xFFE91E63),
                            modifier = Modifier.size(24.dp)
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = stringResource(R.string.language),
                            color = Color.White,
                            fontSize = 16.sp,
                            fontWeight = FontWeight.Medium
                        )
                    }
                    
                    Text(
                        text = LocaleHelper.getLanguageDisplayName(LocaleHelper.getSavedLanguage(LocalContext.current)),
                        color = Color(0xFFE91E63),
                        fontSize = 14.sp
                    )
                    Text(
                        text = stringResource(R.string.language_description),
                        color = Color.Gray,
                        fontSize = 12.sp
                    )
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
        }
    }
}

/**
 * Цветной счетчик в стиле iOS - АДАПТИВНЫЙ
 */
@Composable
fun ColorCounter(
    count: Int,
    color: Color,
    onClick: () -> Unit,
    selectedColorFilter: String?,
    isCompact: Boolean = false
) {
    val textColor = when {
        color == Color(0xFFFFEB3B) || color == Color(0xFF4CAF50) -> Color.Black
        else -> Color.White
    }
    
    // Определяем активен ли этот фильтр
    val isActive = when {
        color == Color(0xFF9C27B0) && selectedColorFilter == "PURPLE" -> true
        color == Color(0xFFFFEB3B) && selectedColorFilter == "NONE" -> true
        color == Color(0xFFF44336) && selectedColorFilter == "RED" -> true
        color == Color(0xFF4CAF50) && selectedColorFilter == "GREEN_BLUE" -> true
        else -> false
    }
    
    Text(
        text = count.toString(),
        color = textColor,
        fontSize = if (isCompact) 14.sp else 16.sp,
        fontWeight = FontWeight.Bold,
        modifier = Modifier
            .background(color, RoundedCornerShape(if (isCompact) 4.dp else 6.dp))
            .then(
                if (isActive) {
                    Modifier.border(2.dp, Color.White, RoundedCornerShape(if (isCompact) 4.dp else 6.dp))
                } else {
                    Modifier
                }
            )
            .clickable { onClick() }
            .padding(
                horizontal = if (isCompact) 8.dp else 12.dp, 
                vertical = if (isCompact) 2.dp else 4.dp
            )
            .widthIn(min = if (isCompact) 24.dp else 40.dp)
    )
} 