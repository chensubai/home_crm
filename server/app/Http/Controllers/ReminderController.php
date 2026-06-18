<?php

namespace App\Http\Controllers;

use App\Http\Controllers\Concerns\AuthorizesFamilyAccess;
use App\Models\Reminder;
use Illuminate\Http\Request;

class ReminderController extends Controller
{
    use AuthorizesFamilyAccess;

    public function index(Request $request)
    {
        $familyId = (int) $request->query('family_id');
        $this->authorizeFamily($request->user(), $familyId);

        return $this->ok(Reminder::where('family_id', $familyId)->get());
    }

    public function store(Request $request)
    {
        $data = $request->validate($this->rules(['family_id', 'title', 'remind_at']));
        $this->authorizeFamily($request->user(), (int) $data['family_id']);

        return $this->ok(Reminder::create($data), 201);
    }

    public function update(Request $request, Reminder $reminder)
    {
        $this->authorizeFamily($request->user(), $reminder->family_id);
        $reminder->update($request->validate($this->rules([], true)));

        return $this->ok($reminder->fresh());
    }

    public function destroy(Request $request, Reminder $reminder)
    {
        $this->authorizeFamily($request->user(), $reminder->family_id);
        $reminder->delete();

        return $this->ok();
    }

    public function complete(Request $request, Reminder $reminder)
    {
        $this->authorizeFamily($request->user(), $reminder->family_id);
        $reminder->update(['completed_at' => now()]);

        return $this->ok($reminder->fresh());
    }

    private function rules(array $required, bool $partial = false): array
    {
        $mark = fn (string $field) => in_array($field, $required, true) ? 'required' : ($partial ? 'sometimes' : 'nullable');

        return [
            'family_id' => [$mark('family_id'), 'integer', 'exists:families,id'],
            'assignee_id' => ['nullable', 'integer', 'exists:users,id'],
            'title' => [$mark('title'), 'string', 'max:160'],
            'kind' => ['nullable', 'in:important_date,periodic_task,item_expiry'],
            'remind_at' => [$mark('remind_at'), 'date'],
            'repeat_rule' => ['nullable', 'in:none,daily,weekly,monthly,yearly'],
            'repeat_value' => ['nullable', 'string', 'max:64'],
            'notes' => ['nullable', 'string', 'max:1000'],
        ];
    }
}
