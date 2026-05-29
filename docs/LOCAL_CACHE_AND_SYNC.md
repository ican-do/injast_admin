# حافظهٔ محلی پرونده‌ها، تصاویر و همگام‌سازی با سرور

این سند روند جدید اپ **Injast Admin** را برای ذخیرهٔ پایدار پرونده‌های هر اتحادیه (`code_co`)، کار آفلاین، دانلود تصاویر، وضعیت ارسال، و آپلود تصاویر به سرور توضیح می‌دهد.

---

## اهداف

1. **حافظهٔ داخلی پایدار** برای همهٔ پرونده‌های همان اتحادیه که کاربر برای آن لاگین کرده است.
2. **دسترسی آفلاین** به همان داده‌ها بدون اینترنت (سوئیچ آنلاین/آفلاین).
3. **ذخیرهٔ فیزیکی تصاویر** (`image_profile`, `image_parvaneh`, `licence_file` و لینک اسناد).
4. **وضعیت همگام‌سازی** قابل فیلتر: ارسال‌نشده / ارسال‌شده / نیاز به ارسال مجدد.
5. **ارسال به سرور همراه با فایل تصویر**؛ در `tbl_parvande` به‌جای لینک اصناف، مسیر سرور (`/pic_injast/...`) ذخیره می‌شود.
6. **پس از ارسال، رکورد از حافظه حذف نمی‌شود** — فقط وضعیت به «ارسال‌شده» تغییر می‌کند.

---

## معماری

```
API اصناف (آنلاین)
    → AsnafBotClient (استخراج متن + _docs_json)
    → ParvandeLocalRepository.upsert
         → SQLite (parvande + media_asset)
         → LocalImageStore (دانلود فایل)

ارسال به سرور
    → ParvandeSyncService.prepareRecordForServer
         → ImageUploadService → POST /upload/image
    → ImportSyncApi (import/session batch + finalize)
    → markSynced (وضعیت synced، بدون حذف)
```

### جداول SQLite

| جدول | نقش |
|------|-----|
| `parvande` | payload JSON، hash محتوا، `sync_status`، زمان fetch/sync |
| `media_asset` | `remote_url`, `local_path`, `server_url` برای هر فیلد تصویر |

### وضعیت‌ها (`sync_status`)

| مقدار | معنی |
|--------|------|
| `local` | در حافظه؛ هنوز به سرور نرفته |
| `synced` | با موفقیت در سرور ثبت شده |
| `dirty` | پس از `synced` دوباره از API گرفته یا ویرایش شده → باید دوباره ارسال شود |

---

## مسیر فایل‌ها روی دستگاه

```
{ApplicationDocuments}/asnaf_cache/{code_co}/{id_parvandeh}/
  image_profile.jpg
  image_parvaneh.jpg
  licence_file.jpg
  doc_0.jpg
  ...
```

---

## سوئیچ آفلاین / آنلاین

- **محل:** نوار بالای صفحهٔ اسناف + صفحهٔ «بازیابی اطلاعات» + صفحهٔ ورود QR.
- **آفلاین:** استخراج/بروزرسانی از API اصناف غیرفعال؛ فقط خواندن از SQLite.
- **آنلاین:** بازیابی، تست ۵ پرونده، و بروزرسانی از API مجاز است.

### فعال‌سازی خودکار آفلاین

اگر `GET .../insert/parvaneh_meta_ping` به سرور پاسخ ندهد (قطع اینترنت یا سرور):

1. در **صفحهٔ ورود QR** دکمهٔ «ادامه در حالت آفلاین» نمایش داده می‌شود (اگر حداقل یک‌بار قبلاً با سرور وارد شده باشید).
2. در **مدیریت پرونده‌ها** لیست از حافظهٔ محلی بارگذاری می‌شود.
3. در **سایت اصناف** سوئیچ آفلاین قفل می‌شود تا زمانی که سرور برگردد.

تنظیم در `SharedPreferences`: `asnaf_offline_mode_v1_{code_co}` و `asnaf_offline_auto_v1_{code_co}`.

## مسیر ذخیرهٔ تصاویر (macOS / Windows / Linux)

```
{ApplicationDocuments}/asnaf_cache/{code_co}/{id_parvandeh}/
  image_profile.jpg
  image_parvaneh.jpg
  licence_file.jpg
  doc_0.jpg
  ...
```

روی macOS معمولاً چیزی شبیه:

`~/Library/Containers/<bundle-id>/Data/Documents/asnaf_cache/...`

در صفحهٔ **مدیریت پرونده‌ها** در حالت آفلاین، همین مسیر در نوار نارنجی نمایش داده می‌شود.

## مدیریت پرونده‌ها در آفلاین

- لیست از `ParvandeCacheListService` (SQLite) خوانده می‌شود.
- تصویر پروفایل با `ParvandeProfileImage`: اول `Image.file` از مسیر محلی، بعد URL شبکه.
- حذف/بازیابی/سطل‌زباله به سرور نیاز دارد و در آفلاین غیرفعال است.

---

## توالی عملیات

### ۱) پر کردن حافظه (آنلاین)

1. لاگین WebView و استخراج JWT.
2. اجرای «بروزرسانی کامل»، «جدیدترین‌ها»، یا تست ۵ پرونده.
3. برای هر `id_parvandeh`:
   - `GET parvaneh/{id}/`
   - `GET docs/?parvaneh={id}&no_page=true`
   - `upsert` در SQLite؛ در صورت تغییر نسبت به نسخهٔ قبلی و `synced` بودن → `dirty`
   - دانلود تصاویر به پوشهٔ محلی

### ۲) مشاهده و فیلتر

- دکمهٔ لیست / بازبینی: فیلتر «همه»، «ارسال‌نشده + بروز»، «ارسال‌شده»، «نیاز ارسال مجدد».
- شمارنده در نوار: تعداد کل و تعداد در صف ارسال.

### ۳) ارسال به سرور

1. فقط رکوردهای `local` و `dirty` انتخاب می‌شوند.
2. برای هر پرونده:
   - آپلود فایل‌های محلی به `POST /upload/image` با `path=parvande/{code_co}`
   - جایگزینی `image_profile`, `image_parvaneh`, `licence_file` و `link_doc` در `_docs_json` با `filePath` برگشتی سرور
3. `import/session` → batch → finalize (همان API قبلی).
4. پس از موفقیت: `markSynced` — رکورد در حافظه می‌ماند.

### ۴) بروزرسانی مجدد از اصناف

- در حالت آنلاین، همان پرونده دوباره fetch می‌شود.
- اگر hash payload عوض شده و قبلاً `synced` بود → `dirty`.
- کاربر با فیلتر «نیاز ارسال مجدد» و دکمه «ارسال» دوباره به سرور می‌فرستد.

### ۵) مصرف در سایر اپلیکیشن‌ها

فیلدهای تصویر در `tbl_parvande` روی سرور مقداری شبیه `/pic_injast/parvande/{code_co}/...` دارند. اپ‌های دیگر باید base URL سرور را به این مسیر اضافه کنند (مثلاً `http://194.5.175.180` + مسیر).

---

## فایل‌های کد (Flutter)

| مسیر | نقش |
|------|-----|
| `lib/local_cache/parvande_local_db.dart` | SQLite |
| `lib/local_cache/parvande_local_repository.dart` | upsert، فیلتر، مهاجرت از SharedPreferences |
| `lib/local_cache/local_image_store.dart` | دانلود تصویر |
| `lib/local_cache/image_upload_service.dart` | آپلود به `/upload/image` |
| `lib/local_cache/parvande_sync_service.dart` | آماده‌سازی قبل از batch |
| `lib/local_cache/offline_mode_prefs.dart` | سوئیچ آفلاین |
| `lib/local_cache/sync_status.dart` | enum و فیلتر |
| `lib/import_sync/import_draft_store.dart` | واسط سطح UI |

## بک‌اند

- آپلود: `POST /upload/image` (`api/routes/upload.js`)
- ذخیرهٔ پرونده و اسناد: `POST /insert/import/session/*` (`api/routes/insert.js`)

---

## محدودیت‌ها

- **نسخهٔ وب:** SQLite در مرورگر پشتیبانی نمی‌شود؛ fallback سبک با SharedPreferences و بدون فایل فیزیکی تصویر.
- **دسکتاپ/موبایل:** SQLite + `sqflite_common_ffi` (در `main.dart` مقداردهی اولیه می‌شود).

---

## مهاجرت از لیست موقت قدیمی

در اولین اجرا پس از به‌روزرسانی، رکوردهای `import_sync_draft_records_v1` از SharedPreferences به SQLite منتقل می‌شوند (یک‌بار per `code_co`).
