/**
 * Messaging Adapter
 * Abstracts Firebase Cloud Messaging for testability
 */

import * as admin from 'firebase-admin';

export interface MessagingAdapter {
  sendEachForMulticast(
    message: admin.messaging.MulticastMessage
  ): Promise<admin.messaging.BatchResponse>;
}

export class FirebaseMessagingAdapter implements MessagingAdapter {
  async sendEachForMulticast(
    message: admin.messaging.MulticastMessage
  ): Promise<admin.messaging.BatchResponse> {
    return admin.messaging().sendEachForMulticast(message);
  }
}

export const defaultMessagingAdapter = new FirebaseMessagingAdapter();

export class FakeMessagingAdapter implements MessagingAdapter {
  private responses: admin.messaging.BatchResponse[] = [];
  private callCount = 0;
  private shouldThrowError = false;
  private errorToThrow: Error | null = null;

  setResponse(response: admin.messaging.BatchResponse): void {
    this.responses.push(response);
  }

  setShouldThrowError(shouldThrow: boolean, error?: Error): void {
    this.shouldThrowError = shouldThrow;
    this.errorToThrow = error || new Error('Simulated FCM error');
  }

  async sendEachForMulticast(
    message: admin.messaging.MulticastMessage
  ): Promise<admin.messaging.BatchResponse> {
    if (this.shouldThrowError) {
      throw this.errorToThrow;
    }

    const response = this.responses[this.callCount] || {
      successCount: message.tokens.length,
      failureCount: 0,
      responses: message.tokens.map(() => ({ success: true, messageId: 'fake_id' })),
    };
    this.callCount++;
    return response;
  }

  reset(): void {
    this.responses = [];
    this.callCount = 0;
    this.shouldThrowError = false;
    this.errorToThrow = null;
  }

  getCallCount(): number {
    return this.callCount;
  }
}
