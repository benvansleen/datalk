import { Context } from 'effect';
import type { Env } from '../types';

export class Environment extends Context.Tag('app/Environment')<Environment, Env>() {}
