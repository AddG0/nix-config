/*
|--------------------------------------------------------------------------
| Theme Controller Routes
|--------------------------------------------------------------------------
|
| Endpoint: /admin/theme
|
*/
Route::group(['prefix' => '/theme'], function () {
    Route::get('/', [Admin\ThemeController::class, 'index'])->name('admin.theme');
    Route::get('/layout', [Admin\ThemeController::class, 'layout'])->name('admin.theme.layout');
    Route::get('/home', [Admin\ThemeController::class, 'home'])->name('admin.theme.home');
    Route::get('/colors', [Admin\ThemeController::class, 'colors'])->name('admin.theme.colors');
    Route::get('/announcement', [Admin\ThemeController::class, 'announcement'])->name('admin.theme.announcement');

    Route::patch('/layout/settings', [Admin\ThemeController::class, 'updateLayout'])
        ->name('admin.theme.layout.update');
    Route::patch('/home/settings', [Admin\ThemeController::class, 'updateHome'])
        ->name('admin.theme.home.update');
    Route::patch('/auth/settings', [Admin\ThemeController::class, 'updateAuth'])
        ->name('admin.theme.auth.update');
    Route::patch('/file-manager/settings', [Admin\ThemeController::class, 'updateFileManager'])
        ->name('admin.theme.file-manager.update');
    Route::patch('/colors/settings', [Admin\ThemeController::class, 'updateColors'])
        ->name('admin.theme.colors.update');
    Route::patch('/announcement/settings', [Admin\ThemeController::class, 'updateAnnouncement'])
        ->name('admin.theme.announcement.update');
});
