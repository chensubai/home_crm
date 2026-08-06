<?php

namespace Tests\Feature;

use Illuminate\Console\Scheduling\Schedule;
use Tests\TestCase;

class ReminderNotificationScheduleTest extends TestCase
{
    public function test_reconcile_command_runs(): void
    {
        $this->artisan('reminders:reconcile-notifications')
            ->expectsOutputToContain('Reconciled ')
            ->assertSuccessful();
    }

    public function test_reconcile_command_is_scheduled_hourly(): void
    {
        $event = collect(app(Schedule::class)->events())
            ->first(fn ($event) => str_contains($event->command ?? '', 'reminders:reconcile-notifications'));

        $this->assertNotNull($event);
        $this->assertSame('0 * * * *', $event->expression);
    }
}
