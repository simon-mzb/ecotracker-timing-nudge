import { redirect } from "next/navigation";
import { getTranslations } from "next-intl/server";
import { isAdmin } from "@/lib/auth";
import AdminLoginForm from "@/components/AdminLoginForm";
import LanguageSwitcher from "@/components/LanguageSwitcher";

export default async function AdminLoginPage() {
  if (await isAdmin()) {
    redirect("/admin");
  }

  const t = await getTranslations("admin.login");

  return (
    <main className="flex min-h-full flex-1 flex-col items-center justify-center px-6 py-10">
      <div className="mb-6 self-end">
        <LanguageSwitcher />
      </div>
      <div className="w-full max-w-sm">
        <h1 className="mb-6 text-center text-xl font-bold text-neutral-800">
          {t("title")}
        </h1>
        <AdminLoginForm />
      </div>
    </main>
  );
}
