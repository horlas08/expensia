import json
import os
import re

replacements = [
    # (file_path, old_string, new_string, key, en_val, ar_val)
    ("lib/app/models/trip_model.dart", "'Unknown Listing'", "'unknown_listing'.tr", "unknown_listing", "Unknown Listing", "قائمة غير معروفة"),
    ("lib/app/modules/payments_and_payouts/views/payments_and_payouts_view.dart", "'Request withdrawal'", "'request_withdrawal'.tr", "request_withdrawal", "Request withdrawal", "طلب سحب"),
    ("lib/app/modules/payments_and_payouts/views/payments_and_payouts_view.dart", "'Withdrawal history'", "'withdrawal_history'.tr", "withdrawal_history", "Withdrawal history", "سجل السحب"),
    ("lib/app/modules/payments_and_payouts/views/payments_and_payouts_view.dart", "'No withdrawals yet'", "'no_withdrawals_yet'.tr", "no_withdrawals_yet", "No withdrawals yet", "لا توجد سحوبات بعد"),
    ("lib/app/modules/calendar/views/calendar_view.dart", "'No listings found to configure calendar'", "'no_listings_found_calendar'.tr", "no_listings_found_calendar", "No listings found to configure calendar", "لم يتم العثور على قوائم لتهيئة التقويم"),
    ("lib/app/modules/inbox/views/inbox_view.dart", "'Search...'", "'search_ellipsis'.tr", "search_ellipsis", "Search...", "بحث..."),
    ("lib/app/modules/transaction_log/views/transaction_log_view.dart", "'Recent Transactions'", "'recent_transactions'.tr", "recent_transactions", "Recent Transactions", "المعاملات الأخيرة"),
    ("lib/app/modules/transaction_log/views/transaction_log_view.dart", "'Royal Points'", "'royal_points'.tr", "royal_points", "Royal Points", "النقاط الملكية"),
    ("lib/app/modules/transaction_log/views/transaction_log_view.dart", "'No transactions yet'", "'no_transactions_yet'.tr", "no_transactions_yet", "No transactions yet", "لا توجد معاملات بعد"),
    ("lib/app/modules/transaction_log/views/transaction_log_view.dart", "'Booking Payment'", "'booking_payment'.tr", "booking_payment", "Booking Payment", "دفع الحجز"),
    ("lib/app/modules/transaction_log/views/transaction_log_view.dart", "'Pending Earning'", "'pending_earning'.tr", "pending_earning", "Pending Earning", "أرباح معلقة"),
    ("lib/app/modules/transaction_log/views/transaction_log_view.dart", "'Points Awarded'", "'points_awarded'.tr", "points_awarded", "Points Awarded", "النقاط الممنوحة"),
    ("lib/app/modules/transaction_log/views/transaction_log_view.dart", "'Withdrawal Request'", "'withdrawal_request_status'.tr", "withdrawal_request_status", "Withdrawal Request", "طلب السحب"),
    ("lib/app/modules/transaction_log/views/transaction_log_view.dart", "'Withdrawal Paid'", "'withdrawal_paid'.tr", "withdrawal_paid", "Withdrawal Paid", "السحب المدفوع"),
    ("lib/app/modules/personal_information/controllers/personal_information_controller.dart", "'Failed to update'", "'failed_to_update'.tr", "failed_to_update", "Failed to update", "فشل التحديث"),
    ("lib/app/modules/otp/views/otp_view.dart", "\"sent to your email\"", "'sent_to_your_email'.tr", "sent_to_your_email", "sent to your email", "تم الإرسال إلى بريدك الإلكتروني"),
    ("lib/app/modules/calendar_config/controllers/calendar_config_controller.dart", "'Listing Calendar'", "'listing_calendar'.tr", "listing_calendar", "Listing Calendar", "تقويم القائمة"),
    ("lib/app/modules/listings/controllers/listings_controller.dart", "'DRAFT'", "'draft_status'.tr", "draft_status", "DRAFT", "مسودة"),
    ("lib/app/modules/listings/controllers/listings_controller.dart", "'PENDING'", "'pending_status'.tr", "pending_status", "PENDING", "قيد الانتظار"),
    ("lib/app/modules/listings/views/listings_view.dart", "'Search listings...'", "'search_listings'.tr", "search_listings", "Search listings...", "البحث في القوائم..."),
    ("lib/app/modules/listings/views/listings_view.dart", "'No listings found'", "'no_listings_found'.tr", "no_listings_found", "No listings found", "لم يتم العثور على قوائم"),
    ("lib/app/modules/listings/views/listings_view.dart", "'PENDING'", "'pending_status'.tr", "-", "-", "-"), 
    ("lib/app/modules/listings/views/listings_view.dart", "'DRAFT'", "'draft_status'.tr", "-", "-", "-"),
    ("lib/app/modules/listings/views/listings_view.dart", "'ACTION_REQUIRED'", "'action_required_status'.tr", "action_required_status", "ACTION REQUIRED", "مطلوب إجراء"),
    ("lib/app/modules/listings/views/listings_view.dart", "'IN_REVIEW'", "'in_review_status'.tr", "in_review_status", "IN REVIEW", "في المراجعة"),
    ("lib/app/modules/reservation/controllers/reservation_controller.dart", "'Error fetching reservations'", "'error_fetching_reservations'.tr", "error_fetching_reservations", "Error fetching reservations", "خطأ في جلب الحجوزات"),
    ("lib/app/modules/reservation/views/reservation_view.dart", "'Complete residential address to publish.'", "'complete_residential_address'.tr", "complete_residential_address", "Complete residential address to publish.", "أكمل العنوان السكني للتمكن من النشر."),
    ("lib/app/modules/payment_method/controllers/payment_method_controller.dart", "'Failed to convert currency'", "'failed_to_convert_currency'.tr", "failed_to_convert_currency", "Failed to convert currency", "فشل في تحويل العملة"),
    ("lib/app/modules/payment_method/controllers/payment_method_controller.dart", "'Payment failed'", "'payment_failed'.tr", "payment_failed", "Payment failed", "فشل الدفع"),
    ("lib/app/modules/payment_method/controllers/payment_method_controller.dart", "'Error: Failed to create booking'", "'error_create_booking'.tr", "error_create_booking", "Error: Failed to create booking", "خطأ: فشل في إنشاء الحجز"),
    ("lib/app/modules/payment_method/controllers/payment_method_controller.dart", "'Points payment is not available'", "'points_payment_not_available'.tr", "points_payment_not_available", "Points payment is not available", "دفع النقاط غير متاح"),
    ("lib/app/modules/payment_method/controllers/payment_method_controller.dart", "'Insufficient royal points'", "'insufficient_royal_points'.tr", "insufficient_royal_points", "Insufficient royal points", "نقاط ملكية غير كافية"),
    ("lib/app/modules/payment_method/views/payment_method_view.dart", "'Royal Points'", "'royal_points'.tr", "-", "-", "-"),
    ("lib/app/modules/payment_method/views/payment_method_view.dart", "'Apple Pay'", "'apple_pay'.tr", "apple_pay", "Apple Pay", "Apple Pay"),
    ("lib/app/modules/payment_method/views/payment_method_view.dart", "'Payment failed'", "'payment_failed'.tr", "-", "-", "-"),
    ("lib/app/modules/payment_method/views/payment_method_view.dart", "\"Contact us for any questions on your booking.\"", "'contact_us_booking_questions'.tr", "contact_us_booking_questions", "Contact us for any questions on your booking.", "اتصل بنا لأي استفسارات حول حجزك."),
    ("lib/app/modules/payment_method/views/payment_method_view.dart", "'Add your card to continue.'", "'add_card_to_continue'.tr", "add_card_to_continue", "Add your card to continue.", "أضف بطاقتك للمتابعة."),
    ("lib/app/modules/payment_method/views/payment_method_view.dart", "'Add card'", "'add_card'.tr", "add_card", "Add card", "إضافة بطاقة"),
    ("lib/app/modules/safety_issue/controllers/safety_issue_controller.dart", "'Safety Incident Report'", "'safety_incident_report'.tr", "safety_incident_report", "Safety Incident Report", "تقرير حادث السلامة"),
    ("lib/app/modules/past_trip/views/past_trip_view.dart", "'No past trips found'", "'no_past_trips'.tr", "no_past_trips", "No past trips found", "لم يتم العثور على رحلات سابقة"),
    ("lib/app/modules/past_trip/views/past_trip_view.dart", "'When you complete trips, they will appear here.'", "'when_you_complete_trips'.tr", "when_you_complete_trips", "When you complete trips, they will appear here.", "عند إكمال الرحلات، ستظهر هنا."),
    ("lib/app/modules/place_details/views/gallery_view.dart", "'All Photos'", "'all_photos'.tr", "all_photos", "All Photos", "كل الصور"),
    ("lib/app/modules/place_details/views/place_details_view.dart", "'per night'", "'per_night_lowercase'.tr", "per_night_lowercase", "per night", "في الليلة"),
    ("lib/app/modules/place_details/views/place_details_view.dart", "'Select dates'", "'select_dates'.tr", "select_dates", "Select dates", "حدد التواريخ"),
    ("lib/app/modules/filter/views/filter_view.dart", "'Saudi Arabia'", "'saudi_arabia'.tr", "saudi_arabia", "Saudi Arabia", "المملكة العربية السعودية"),
    ("lib/app/modules/filter/views/filter_view.dart", "'United Arab Emirates'", "'uae'.tr", "uae", "United Arab Emirates", "الإمارات العربية المتحدة"),
    ("lib/app/modules/trips/controllers/trips_controller.dart", "'Error fetching trips'", "'error_fetching_trips'.tr", "error_fetching_trips", "Error fetching trips", "خطأ في جلب الرحلات"),
    ("lib/app/modules/trip_details/views/trip_details_view.dart", "'Host information currently unavailable.'", "'host_info_unavailable'.tr", "host_info_unavailable", "Host information currently unavailable.", "معلومات المضيف غير متاحة حالياً."),
    ("lib/app/services/listing/listing_service.dart", "'Provide exactly one of listingId, serviceListingId, experienceListingId'", "'provide_exactly_one_id'.tr", "provide_exactly_one_id", "Provide exactly one of listingId, serviceListingId, experienceListingId", "قم بتوفير واحد فقط من معرّف القائمة أو الخدمة أو التجربة"),
]

for file_path, old_str, new_str, key, en_val, ar_val in replacements:
    path = os.path.join("/Users/user/project/mobile/awals", file_path)
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
        if old_str in content:
            content = content.replace(old_str, new_str)
            with open(path, "w", encoding="utf-8") as f:
                f.write(content)
            print(f"Replaced in {file_path}")

en_file = "/Users/user/project/mobile/awals/assets/lang/lang_en.json"
ar_file = "/Users/user/project/mobile/awals/assets/lang/lang_ar.json"

with open(en_file, "r") as f: en_data = json.load(f)
with open(ar_file, "r") as f: ar_data = json.load(f)

for _, _, _, key, en_val, ar_val in replacements:
    if key != "-":
        en_data[key] = en_val
        ar_data[key] = ar_val

with open(en_file, "w") as f: json.dump(en_data, f, ensure_ascii=False, indent=2)
with open(ar_file, "w") as f: json.dump(ar_data, f, ensure_ascii=False, indent=2)
print("Translations added to JSON files.")
