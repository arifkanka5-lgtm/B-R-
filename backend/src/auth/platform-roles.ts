/**
 * BÖRÜ platform rozetleri yalnızca sunucu yapılandırmasından gelir.
 * İstemci kendi yetkisini seçemez. Listeye kullanıcı publicId değerleri eklenir.
 */
export type BoruPlatformRole = 'SUPER_ADMIN' | 'ADMIN' | 'MODERATOR' | 'USER';

function includesPublicId(key: string, publicId: string): boolean {
  const configured = process.env[key] ?? '';
  return configured.split(/[,;\s]+/).some((id) => id === publicId);
}

export function getPlatformRole(publicId: string): BoruPlatformRole {
  if (includesPublicId('BORU_SUPER_ADMIN_PUBLIC_IDS', publicId)) return 'SUPER_ADMIN';
  if (includesPublicId('BORU_ADMIN_PUBLIC_IDS', publicId)) return 'ADMIN';
  if (includesPublicId('BORU_MODERATOR_PUBLIC_IDS', publicId)) return 'MODERATOR';
  return 'USER';
}
