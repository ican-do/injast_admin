# API حق عضویت (مطالبات صنفی)

پیاده‌سازی سرور: `injast_v3/new_backend/api/routes/hagh_ozviat.js`  
مایگریشن جدول: `injast_v3/new_backend/api/migrations/add_tbl_hagh_ozviat.sql`

### فایل ورودی

فقط **CSV UTF-8** (در Excel: Save As → CSV UTF-8). هر ردیف باید «کد صنفی» خودش را داشته باشد.

### استقرار روی سرور ویندوز

1. یک‌بار SQL مایگریشن را روی `db_asnaf` اجرا کنید.
2. فایل‌های به‌روز `api/routes/hagh_ozviat.js` و `api/routes/index.js` را کپی کنید.
3. سرور پورت **8080** (`app_dd.js`) را ری‌استارت کنید.
4. راهنمای کامل: `injast_v3/new_backend/DEPLOY_HAGH_OZVIAT.md`

---

## جدول: `tbl_hagh_ozviat`

| ستون | نوع | توضیح |
|------|-----|--------|
| `id` | INT PK AI | |
| `code_co` | VARCHAR | کد اتحادیه |
| `shenase_store` | VARCHAR(20) | کد صنفی (۱۰ رقم، با صفر ابتدا) |
| `onvan` | VARCHAR(255) | عنوان (مثلاً حق عضویت سال 1404) |
| `mablagh_rial` | BIGINT | مبلغ به ریال |
| `sal` | VARCHAR(4) | سال شمسی |
| `tarikh_ijad` | VARCHAR(64) | تاریخ ایجاد در سامانه اصناف |
| `noe_eblagh` | VARCHAR(64) | نوع ابلاغ |
| `vaziyat` | VARCHAR(64) | وضعیت (در انتظار پرداخت / تایید شده / …) |
| `rade_sanfi` | VARCHAR(64) | رده صنفی |
| `onvan_raste` | TEXT | عنوان رسته (ممکن است در XLS طولانی باشد) |
| `created_at` | DATETIME | زمان ثبت در سرور شما |

ایندکس: `(code_co, shenase_store)`

---

## ۱) خلاصهٔ حق عضویت همهٔ اعضا (برای کارت پرونده)

```
GET /select/select_hagh_ozviat_index/{code_co}
```

پاسخ JSON (آرایه، یک ردیف به ازای هر کد صنفی که رکورد دارد):

```json
[
  {
    "shenase_store": "0012345678",
    "pending_rial": 1500000,
    "confirmed_rial": 500000,
    "row_count": 3
  }
]
```

---

## ۲) دریافت حق عضویت یک عضو

```
GET /select/select_hagh_ozviat/{code_co}/{shenase_store}
```

پاسخ JSON (آرایه):

```json
[
  {
    "onvan": "پرداخت حق عضویت سال 1404",
    "mablagh_rial": "18000000",
    "sal": "1404",
    "tarikh_ijad": "1405/02/06 , 10:27",
    "noe_eblagh": "توسط کاربر",
    "vaziyat": "در انتظار پرداخت",
    "rade_sanfi": "رده ۱",
    "onvan_raste": "خرده فروشی پوشاک زنانه"
  }
]
```

---

## ۲) همگام‌سازی پس از بارگذاری XLS

برای هر `shenase_store` در بدنه: **حذف همهٔ ردیف‌های قبلی** همان `(code_co, shenase_store)` و **درج ردیف‌های جدید**.

```
POST /insert/hagh_ozviat/sync
Content-Type: application/json
```

```json
{
  "code_co": "123456",
  "records": [
    {
      "shenase_store": "0158702107",
      "onvan": "پرداخت حق عضویت سال 1403",
      "mablagh_rial": 12000000,
      "sal": "1403",
      "tarikh_ijad": "1403/06/29 , 08:26",
      "noe_eblagh": "به صورت سیستمی",
      "vaziyat": "تایید شده",
      "rade_sanfi": "رده ۱",
      "onvan_raste": "خرده فروشی پوشاک مردانه"
    }
  ]
}
```

پاسخ:

```json
{
  "ok": true,
  "members_replaced": 3264,
  "rows_inserted": 6278,
  "errors": []
}
```

منطق سرور (خلاصه):

1. گروه‌بندی `records` بر اساس `shenase_store`
2. برای هر گروه: `DELETE FROM tbl_hagh_ozviat WHERE code_co=? AND shenase_store=?`
3. `INSERT` ردیف‌های همان گروه

---

## وضعیت‌های شناخته‌شده در فایل XLS

| `vaziyat` | معنی در UI |
|-----------|------------|
| در انتظار پرداخت | بدهی باز |
| تایید شده | پرداخت/تسویه شده |
| پرداخت خارج از سامانه | (اختیاری: مانند تایید شده) |
| حذف شده | نادیده در جمع‌بندی |
