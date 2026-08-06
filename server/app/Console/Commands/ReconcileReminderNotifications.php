<?php

namespace App\Console\Commands;

use App\Models\Reminder;
use Illuminate\Console\Command;

class ReconcileReminderNotifications extends Command
{
    protected $signature = 'reminders:reconcile-notifications';

    protected $description = 'Reconcile active reminders for client notification scheduling';

    public function handle(): int
    {
        $count = Reminder::query()
            ->where('is_enabled', true)
            ->whereNull('completed_at')
            ->count();

        $this->info("Reconciled {$count} active reminders.");

        return self::SUCCESS;
    }
}
