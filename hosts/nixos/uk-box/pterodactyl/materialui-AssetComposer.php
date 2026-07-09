<?php

namespace Pterodactyl\Http\ViewComposers;

use Illuminate\View\View;
use Pterodactyl\Services\Helpers\AssetHashService;
use Pterodactyl\Contracts\Repository\SettingsRepositoryInterface;

class AssetComposer
{
    /**
     * AssetComposer constructor.
     */
    public function __construct(
        private AssetHashService $assetHashService,
        private SettingsRepositoryInterface $settings
    ) {
    }

    /**
     * Provide access to the asset service in the views.
     */
    public function compose(View $view): void
    {
        $view->with('asset', $this->assetHashService);
        $view->with('siteConfiguration', [
            'name' => config('app.name') ?? 'Pterodactyl',
            'locale' => config('app.locale') ?? 'en',
            'recaptcha' => [
                'enabled' => config('recaptcha.enabled', false),
                'siteKey' => config('recaptcha.website_key') ?? '',
            ],
            'theme' => [
                'discordLink' => $this->settings->get('settings:theme:discord_link', ''),
                'billingLink' => $this->settings->get('settings:theme:billing_link', ''),
                'supportLink' => $this->settings->get('settings:theme:support_link', ''),
                'statusLink' => $this->settings->get('settings:theme:status_link', ''),
                'showDiscordLink' => (bool) $this->settings->get('settings:theme:show_discord_link', true),
                'showBillingLink' => (bool) $this->settings->get('settings:theme:show_billing_link', true),
                'showSupportLink' => (bool) $this->settings->get('settings:theme:show_support_link', true),
                'showStatusLink' => (bool) $this->settings->get('settings:theme:show_status_link', true),
                'enableDiscordWidget' => (bool) $this->settings->get('settings:theme:enable_discord_widget', false),
                'discordWidgetId' => $this->settings->get('settings:theme:discord_widget_id', ''),
                'logoUrl' => $this->settings->get('theme:logo_url', null),
                'onlyLogo' => $this->settings->get('theme:only_logo', false),
                'blurIpAddresses' => $this->settings->get('theme:blur_ip_addresses', false),
                'serverLayouts' => [
                    'enabledLayouts' => json_decode($this->settings->get('settings:theme:server_layouts_enabled', '["default", "compact", "banner", "grid"]')),
                    'defaultLayout' => $this->settings->get('settings:theme:server_layouts_default', 'default'),
                    'updatedAt' => (int) $this->settings->get('settings:theme:server_layouts_updated', 0),
                ],
                'announcement' => [
                    'enabled' => (bool) $this->settings->get('settings:theme:announcement:enabled', false),
                    'type' => $this->settings->get('settings:theme:announcement:type', 'warning'),
                    'message' => $this->settings->get('settings:theme:announcement:message', ''),
                    'allowDismiss' => (bool) $this->settings->get('settings:theme:announcement:allow_dismiss', true),
                    'variant' => $this->settings->get('settings:theme:announcement:variant', 'standard'),
                    'customIcon' => (bool) $this->settings->get('settings:theme:announcement:custom_icon', false),
                ],
                'snackbarPosition' => [
                    'vertical' => $this->settings->get('theme:snackbar_position_vertical', 'bottom'),
                    'horizontal' => $this->settings->get('theme:snackbar_position_horizontal', 'right'),
                ],
                'layoutType' => $this->settings->get('theme:layout_type', 'navbar'),
                'sidebarServerLinks' => (bool) $this->settings->get('theme:sidebar_server_links', false),
                'fixedNavigation' => (bool) $this->settings->get('theme:fixed_navigation', false),
                'navigationBarColor' => $this->settings->get('theme:navigation_bar_color', ''),
                'defaultPreset' => $this->settings->get('theme:default_preset', 'blue'),
                'auth' => [
                    'background' => $this->settings->get('theme:auth:background', 'https://bingw.jasonzeng.dev/?w=1920'),
                    'layout' => $this->settings->get('theme:auth:layout', 'default'),
                    'enableBlur' => (bool) $this->settings->get('theme:auth:enableBlur', true),
                    'blurAmount' => (int) $this->settings->get('theme:auth:blurAmount', 10),
                ],
                'fileManager' => [
                    'layout' => $this->settings->get('theme:file_manager:layout', 'list'),
                    'gridSize' => (int) $this->settings->get('theme:file_manager:grid_size', 120),
                    'showFileInfo' => (bool) $this->settings->get('theme:file_manager:show_file_info', true),
                ],
                'roundness' => (int) $this->settings->get('theme:roundness', 5),
                'customColors' => json_decode($this->settings->get('theme:custom_colors', '{}'), true),
            ],
        ]);
    }
}
