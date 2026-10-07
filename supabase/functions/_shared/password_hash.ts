import bcrypt from 'npm:bcryptjs@2.4.3';

export function hashPassword(password: string): Promise<string> {
  return new Promise((resolve, reject) => {
    bcrypt.hash(password, 12, (error, hash) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(hash);
    });
  });
}
