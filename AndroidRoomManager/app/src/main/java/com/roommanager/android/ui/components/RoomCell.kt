package com.roommanager.android.ui.components

import android.util.Log
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.res.stringResource
import com.roommanager.android.model.Room
import com.roommanager.android.model.RoomColor
import com.roommanager.android.utils.*
import com.roommanager.android.R
import java.text.SimpleDateFormat
import java.util.*

/**
 * Стили ячеек - точно как в iOS
 */
enum class CellStyle {
    FLAT,       // Плоский стиль (основной)
    CLASSIC     // Классический 3D стиль
}

/**
 * Компонент ячейки комнаты с поддержкой двух стилей как в iOS
 * - FLAT: плоский стиль без объемности (основной)
 * - CLASSIC: классический 3D стиль с градиентами и тенями
 */
@Composable
fun RoomCell(
    room: Room,
    modifier: Modifier = Modifier,
    cellStyle: CellStyle = CellStyle.FLAT, // Плоский стиль по умолчанию
    onClick: ((Room) -> Unit)? = null
) {
    // Логи для отладки индикаторов
    if (room.isMarked || room.isDeepCleaned || room.isCompletedBefore930) {
        Log.d("RoomCell", "Комната ${room.number}: isMarked=${room.isMarked}, isDeepCleaned=${room.isDeepCleaned}, isCompletedBefore930=${room.isCompletedBefore930}")
    }
    
    val backgroundColor = getExactIOSBackgroundColor(room.color)
    val textColor = getExactIOSTextColor(room.color)
    
    // Основное содержимое (одинаковое для обоих стилей)
    val content = @Composable {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(responsiveSmallSpacing()), // Адаптивные отступы
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            // Номер комнаты - увеличенный адаптивный размер шрифта
            Text(
                text = room.number,
                color = textColor,
                fontSize = ResponsiveFontSizes.roomNumber(), // Увеличенный адаптивный размер
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Clip // Обрезаем если не помещается
            )
            
            // Время для всех ячеек - адаптивный размер
            val displayTime = getDisplayTimeForRoom(room)
            if (displayTime != null) {
                Spacer(modifier = Modifier.height(responsiveDp(1f)))
                Text(
                    text = displayTime,
                    color = textColor,
                    fontSize = ResponsiveFontSizes.roomTime(), // Увеличенный адаптивный размер
                    fontWeight = FontWeight.SemiBold,
                    textAlign = TextAlign.Center,
                    maxLines = 1,
                    overflow = TextOverflow.Clip // Обрезаем если не помещается
                )
            }
        }
    }
    
    // Применяем стиль
    when (cellStyle) {
        CellStyle.FLAT -> {
            ApplyFlatStyle(
                modifier = modifier,
                room = room,
                backgroundColor = backgroundColor,
                content = content
            )
        }
        CellStyle.CLASSIC -> {
            ApplyClassicStyle(
                modifier = modifier,
                room = room,
                backgroundColor = backgroundColor,
                content = content
            )
        }
    }
}

/**
 * ПЛОСКИЙ СТИЛЬ - точно как в iOS
 * Простой сплошной цвет, скругление 8dp, без теней и градиентов
 */
@Composable
private fun ApplyFlatStyle(
    modifier: Modifier,
    room: Room,
    backgroundColor: Color,
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(1f) // Квадратные ячейки как в iOS
            .clip(RoundedCornerShape(responsiveDp(8f))) // Адаптивное скругление
            .background(
                if (room.color == RoomColor.WHITE) {
                    Color.White // Белые ячейки - простой белый цвет
                } else {
                    backgroundColor // Цветные ячейки - сплошной цвет
                }
            )
    ) {
        // Основное содержимое
        content()
        
        // DC эффект (диагональные полоски для Deep Clean) - точно как в iOS
        if (room.isDeepCleaned) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                drawIOSZebraStripes(this, room.color)
            }
        }
        
        // Плавающий маркер помеченных комнат - адаптивный размер
        if (room.isMarked) {
            Box(
                modifier = Modifier
                    .size(responsiveSmallIconSize()) // Адаптивный размер
                    .align(Alignment.TopEnd)
                    .offset(x = -responsiveSmallSpacing(), y = responsiveSmallSpacing())
                    .shadow(responsiveDp(2f), CircleShape)
                    .clip(CircleShape)
                    .background(Color(0xFF00F314)) // Точный зеленый цвет как в iOS
            )
        }
        
        // Индикатор выполнения до 9:30 (clock icon) - адаптивный размер
        if (room.isCompletedBefore930 && room.color != RoomColor.WHITE) {
            Box(
                modifier = Modifier
                    .size(responsiveDp(12f))
                    .align(Alignment.BottomStart)
                    .offset(x = responsiveSmallSpacing(), y = -responsiveSmallSpacing())
                    .clip(CircleShape)
                    .background(Color(0xFFFF9800))
            ) {
                // Маленькая иконка часов - адаптивный размер
                Icon(
                    Icons.Default.Schedule,
                    contentDescription = "Completed before 9:30",
                    tint = Color.White,
                    modifier = Modifier
                        .size(responsiveDp(8f))
                        .align(Alignment.Center)
                )
            }
        }
        
        // Граница для белых комнат - адаптивная ширина
        if (room.color == RoomColor.WHITE) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .border(
                        width = responsiveDp(1f),
                        color = Color.Gray.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(responsiveDp(8f))
                    )
            )
        }
    }
}

/**
 * КЛАССИЧЕСКИЙ 3D СТИЛЬ - точно как в iOS
 * 3D градиенты, скругление 10dp, тени, внутренние рамки, поворот
 */
@Composable
private fun ApplyClassicStyle(
    modifier: Modifier,
    room: Room,
    backgroundColor: Color,
    content: @Composable () -> Unit
) {
    Box(
        modifier = modifier
            .fillMaxWidth()
            .aspectRatio(1f) // Квадратные ячейки как в iOS
            .shadow(
                elevation = responsiveDp(5f),
                shape = RoundedCornerShape(responsiveDp(10f)),
                spotColor = Color.Black.copy(alpha = 0.25f)
            )
            .clip(RoundedCornerShape(responsiveDp(10f)))
            .background(
                brush = if (room.color == RoomColor.WHITE) {
                    // Белые ячейки - градиент для объемности
                    Brush.verticalGradient(
                        colors = listOf(
                            Color.White,
                            Color.White.copy(alpha = 0.85f)
                        )
                    )
                } else {
                    // Цветные ячейки - 3D градиент как в iOS
                    Brush.verticalGradient(
                        colors = listOf(
                            adjustBrightness(backgroundColor, 1.2f), // Светлее сверху
                            backgroundColor,                          // Основной цвет в центре
                            adjustBrightness(backgroundColor, 0.8f)  // Темнее снизу
                        )
                    )
                }
            )
            .then(
                if (room.color != RoomColor.WHITE) {
                    // Добавляем внутреннюю рамку для объемности
                    Modifier.border(
                        width = responsiveDp(1.5f),
                        brush = Brush.linearGradient(
                            colors = listOf(
                                Color.White.copy(alpha = 0.6f),    // Светлая рамка сверху
                                Color.Black.copy(alpha = 0.3f)     // Темная рамка снизу
                            )
                        ),
                        shape = RoundedCornerShape(responsiveDp(10f))
                    )
                } else {
                    Modifier
                }
            )
            .graphicsLayer {
                // 3D эффект поворота как в iOS
                rotationX = 3f
            }
    ) {
        // Основное содержимое
        content()
        
        // DC эффект (диагональные полоски для Deep Clean) - точно как в iOS
        if (room.isDeepCleaned) {
            Canvas(modifier = Modifier.fillMaxSize()) {
                drawIOSZebraStripes(this, room.color)
            }
        }
        
        // Плавающий маркер помеченных комнат - адаптивный размер
        if (room.isMarked) {
            Box(
                modifier = Modifier
                    .size(responsiveSmallIconSize()) // Адаптивный размер
                    .align(Alignment.TopEnd)
                    .offset(x = -responsiveSmallSpacing(), y = responsiveSmallSpacing())
                    .shadow(responsiveDp(2f), CircleShape)
                    .clip(CircleShape)
                    .background(Color(0xFF00F314)) // Точный зеленый цвет как в iOS
            )
        }
        
        // Индикатор выполнения до 9:30 (clock icon) - адаптивный размер
        if (room.isCompletedBefore930 && room.color != RoomColor.WHITE) {
            Box(
                modifier = Modifier
                    .size(responsiveDp(12f))
                    .align(Alignment.BottomStart)
                    .offset(x = responsiveSmallSpacing(), y = -responsiveSmallSpacing())
                    .clip(CircleShape)
                    .background(Color(0xFFFF9800))
            ) {
                // Маленькая иконка часов - адаптивный размер
                Icon(
                    Icons.Default.Schedule,
                    contentDescription = "Completed before 9:30",
                    tint = Color.White,
                    modifier = Modifier
                        .size(responsiveDp(8f))
                        .align(Alignment.Center)
                )
            }
        }
        
        // Граница для белых комнат - адаптивная ширина
        if (room.color == RoomColor.WHITE) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .border(
                        width = responsiveDp(1f),
                        color = Color.Gray.copy(alpha = 0.5f),
                        shape = RoundedCornerShape(responsiveDp(10f))
                    )
            )
        }
    }
}

/**
 * Возвращает ТОЧНЫЕ цвета как в iOS версии
 */
private fun getExactIOSBackgroundColor(status: RoomColor): Color {
    return when (status) {
        RoomColor.NONE -> Color(red = 1.0f, green = 0.85f, blue = 0.0f)    // Яркий желтый
        RoomColor.RED -> Color(red = 1.0f, green = 0.15f, blue = 0.15f)    // Яркий красный
        RoomColor.GREEN -> Color(red = 0.0f, green = 0.95f, blue = 0.2f)   // Сочный зеленый
        RoomColor.PURPLE -> Color(red = 0.85f, green = 0.2f, blue = 1.0f)  // Яркий фиолетовый
        RoomColor.BLUE -> Color(red = 0.0f, green = 0.45f, blue = 1.0f)    // Насыщенный синий
        RoomColor.WHITE -> Color.White
    }
}

/**
 * Возвращает цвет текста - всегда черный по требованию
 */
private fun getExactIOSTextColor(status: RoomColor): Color {
    return Color.Black // Все тексты в ячейках черные
}

/**
 * Изменяет яркость цвета для градиента - как в iOS
 */
private fun adjustBrightness(color: Color, factor: Float): Color {
    return Color(
        red = (color.red * factor).coerceIn(0f, 1f),
        green = (color.green * factor).coerceIn(0f, 1f),
        blue = (color.blue * factor).coerceIn(0f, 1f),
        alpha = color.alpha
    )
}

/**
 * Рисует диагональные полоски ТОЧНО как в iOS ZebraAnimationView
 */
private fun drawIOSZebraStripes(drawScope: DrawScope, roomColor: RoomColor) {
    val stripeWidth = 15f
    val stripeSpacing = 18f // Увеличены промежутки как в iOS
    val totalStripePatternWidth = stripeWidth + stripeSpacing
    
    // Цвет полосок точно как в iOS
    val stripeColor = when (roomColor) {
        RoomColor.NONE -> Color.Black.copy(alpha = 0.4f) // Для желтого темные полосы
        RoomColor.WHITE -> Color.Black.copy(alpha = 0.3f) // Для белого темные полосы
        RoomColor.RED, RoomColor.GREEN, RoomColor.BLUE, RoomColor.PURPLE -> 
            Color.White.copy(alpha = 0.5f) // Для темных цветов белые полосы
    }
    
    val width = drawScope.size.width
    val height = drawScope.size.height
    val numberOfStripes = ((width + height) / totalStripePatternWidth * 3).toInt()
    
    for (i in -numberOfStripes..numberOfStripes) {
        val xOffset = i * totalStripePatternWidth
        
        val path = Path().apply {
            // Диагональные линии точно как в iOS
            moveTo(xOffset - height, 0f)
            lineTo(xOffset + stripeWidth - height, 0f)
            lineTo(xOffset + stripeWidth, height)
            lineTo(xOffset, height)
            close()
        }
        
        drawScope.drawPath(path, stripeColor)
    }
}

/**
 * Возвращает строку времени для отображения под номером в американском формате AM/PM
 */
private fun getDisplayTimeForRoom(room: Room): String? {
    val formatter = SimpleDateFormat("hh:mm a", Locale.US) // Американский формат AM/PM
    
    return when (room.color) {
        RoomColor.NONE -> room.noneTimestamp?.toDate()?.let { formatter.format(it) }
        RoomColor.PURPLE -> room.availableTime // Это строка, оставляем как есть
        RoomColor.RED -> room.redTimestamp?.toDate()?.let { formatter.format(it) }
        RoomColor.GREEN -> room.greenTimestamp?.toDate()?.let { formatter.format(it) }
        RoomColor.BLUE -> room.blueTimestamp?.toDate()?.let { formatter.format(it) }
        RoomColor.WHITE -> null // Белые комнаты не показывают время
    }
}

// Превью для разработки - показываем оба стиля
@Preview(showBackground = true)
@Composable
fun RoomCellPreview() {
    Column(
        modifier = Modifier.padding(responsiveContentPadding()),
        verticalArrangement = Arrangement.spacedBy(responsiveSpacing())
    ) {
        Text(stringResource(R.string.flat_style_main), fontWeight = FontWeight.Bold)
        Row(
            horizontalArrangement = Arrangement.spacedBy(responsiveSpacing())
        ) {
            // Плоский стиль
            RoomCell(
                room = Room(id = "1", number = "101", color = RoomColor.NONE),
                cellStyle = CellStyle.FLAT,
                modifier = Modifier.size(responsiveDp(80f))
            )
            RoomCell(
                room = Room(id = "2", number = "102", color = RoomColor.RED, isMarked = true),
                cellStyle = CellStyle.FLAT,
                modifier = Modifier.size(responsiveDp(80f))
            )
            RoomCell(
                room = Room(id = "3", number = "103", color = RoomColor.GREEN, isDeepCleaned = true),
                cellStyle = CellStyle.FLAT,
                modifier = Modifier.size(responsiveDp(80f))
            )
        }
        
        Text(stringResource(R.string.classic_3d_style), fontWeight = FontWeight.Bold)
        Row(
            horizontalArrangement = Arrangement.spacedBy(responsiveSpacing())
        ) {
            // Классический стиль
            RoomCell(
                room = Room(id = "4", number = "104", color = RoomColor.PURPLE, availableTime = "14:30"),
                cellStyle = CellStyle.CLASSIC,
                modifier = Modifier.size(responsiveDp(80f))
            )
            RoomCell(
                room = Room(id = "5", number = "105", color = RoomColor.BLUE),
                cellStyle = CellStyle.CLASSIC,
                modifier = Modifier.size(responsiveDp(80f))
            )
            RoomCell(
                room = Room(id = "6", number = "106", color = RoomColor.WHITE),
                cellStyle = CellStyle.CLASSIC,
                modifier = Modifier.size(responsiveDp(80f))
            )
        }
    }
} 