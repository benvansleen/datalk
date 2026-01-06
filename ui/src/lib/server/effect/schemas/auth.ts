import { Schema } from 'effect';

// Email pattern for validation
const EmailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

// Signup request schema
export class SignupRequest extends Schema.Class<SignupRequest>('SignupRequest')({
  name: Schema.String.pipe(
    Schema.minLength(3, { message: () => 'Name must be at least 3 characters' }),
  ),
  email: Schema.String.pipe(
    Schema.pattern(EmailPattern, {
      message: () => 'Invalid email format',
    }),
  ),
  password: Schema.String.pipe(
    Schema.minLength(8, { message: () => 'Password must be at least 8 characters' }),
  ),
}) {}

// Login request schema
export class LoginRequest extends Schema.Class<LoginRequest>('LoginRequest')({
  email: Schema.String.pipe(
    Schema.pattern(EmailPattern, {
      message: () => 'Invalid email format',
    }),
  ),
  password: Schema.String.pipe(
    Schema.minLength(8, { message: () => 'Password must be at least 8 characters' }),
  ),
}) {}
