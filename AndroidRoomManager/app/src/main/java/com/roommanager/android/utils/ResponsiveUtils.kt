package com.roommanager.android.utils

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Утилиты для создания адаптивного дизайна
 * Все размеры масштабируются пропорционально размеру экрана
 */

/**
 * Базовая ширина экрана для расчета пропорций (360dp - стандартный Android экран)
 */
private const val BASE_SCREEN_WIDTH_DP = 360f

/**
 * Получить адаптивный размер в dp на основе ширины экрана
 */
@Composable
fun responsiveDp(baseDp: Float): Dp {
    val configuration = LocalConfiguration.current
    val screenWidthDp = configuration.screenWidthDp
    val scaleFactor = screenWidthDp / BASE_SCREEN_WIDTH_DP
    return (baseDp * scaleFactor).dp
}

/**
 * Получить адаптивный размер текста в sp на основе ширины экрана
 */
@Composable
fun responsiveSp(baseSp: Float): TextUnit {
    val configuration = LocalConfiguration.current
    val screenWidthDp = configuration.screenWidthDp
    val scaleFactor = screenWidthDp / BASE_SCREEN_WIDTH_DP
    // Ограничиваем масштабирование текста для лучшей читаемости
    val limitedScale = scaleFactor.coerceIn(0.8f, 1.4f)
    return (baseSp * limitedScale).sp
}

/**
 * Получить размер ячейки комнаты адаптивно
 * На маленьких экранах ячейки меньше, на больших - больше
 */
@Composable
fun responsiveCellSize(): Dp {
    val configuration = LocalConfiguration.current
    val screenWidthDp = configuration.screenWidthDp
    // На экране должно помещаться 5 колонок с минимальными отступами
    val availableWidth = screenWidthDp - 16 // Отступы по краям
    val cellSize = availableWidth / 5f
    return cellSize.dp
}

/**
 * Получить адаптивную высоту верхней панели
 */
@Composable
fun responsiveTopBarHeight(): Dp {
    return responsiveDp(56f) // Стандартная высота TopBar
}

/**
 * Получить адаптивные отступы для контента
 */
@Composable
fun responsiveContentPadding(): Dp {
    return responsiveDp(16f)
}

/**
 * Получить адаптивные отступы между элементами
 */
@Composable
fun responsiveSpacing(): Dp {
    return responsiveDp(8f)
}

/**
 * Получить адаптивные маленькие отступы
 */
@Composable
fun responsiveSmallSpacing(): Dp {
    return responsiveDp(4f)
}

/**
 * Получить адаптивный размер иконки
 */
@Composable
fun responsiveIconSize(): Dp {
    return responsiveDp(24f)
}

/**
 * Получить адаптивный размер маленькой иконки
 */
@Composable
fun responsiveSmallIconSize(): Dp {
    return responsiveDp(16f)
}

/**
 * Размеры шрифтов - адаптивные
 */
object ResponsiveFontSizes {
    @Composable
    fun large(): TextUnit = responsiveSp(20f)
    
    @Composable
    fun medium(): TextUnit = responsiveSp(16f)
    
    @Composable
    fun normal(): TextUnit = responsiveSp(14f)
    
    @Composable
    fun small(): TextUnit = responsiveSp(12f)
    
    @Composable
    fun tiny(): TextUnit = responsiveSp(10f)
    
    // Специальные размеры для ячеек комнат - увеличены но ограничены размером ячейки
    @Composable
    fun roomNumber(): TextUnit {
        val configuration = LocalConfiguration.current
        val screenWidthDp = configuration.screenWidthDp
        val cellSize = (screenWidthDp - 16) / 5f // Размер ячейки
        
        // Масштабируем шрифт относительно размера ячейки, но не меньше 18sp и не больше 32sp
        val fontSize = (cellSize * 0.35f).coerceIn(18f, 32f)
        return fontSize.sp
    }
    
    @Composable
    fun roomTime(): TextUnit {
        val configuration = LocalConfiguration.current
        val screenWidthDp = configuration.screenWidthDp
        val cellSize = (screenWidthDp - 16) / 5f // Размер ячейки
        
        // Масштабируем шрифт времени относительно размера ячейки, но не меньше 11sp и не больше 18sp
        val fontSize = (cellSize * 0.18f).coerceIn(11f, 18f)
        return fontSize.sp
    }
}

/**
 * Проверить, является ли экран компактным (маленьким)
 */
@Composable
fun isCompactScreen(): Boolean {
    val configuration = LocalConfiguration.current
    return configuration.screenWidthDp < 400
}

/**
 * Проверить, является ли экран большим
 */
@Composable
fun isLargeScreen(): Boolean {
    val configuration = LocalConfiguration.current
    return configuration.screenWidthDp > 600
} 