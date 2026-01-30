/**
 * Time Adapter - Converts various time formats to ISO strings
 * Handles Firestore Timestamp, Date, string, number, and null
 */

/**
 * Converts various time formats to ISO string
 * @param value - Firestore Timestamp, Date, string, number, or null
 * @returns ISO string or null
 */
export function toIsoString(value: any): string | null {
  if (!value) {
    return null;
  }

  // Firestore Timestamp (has toDate method)
  if (value && typeof value.toDate === 'function') {
    try {
      return value.toDate().toISOString();
    } catch (err) {
      console.warn('Failed to convert Firestore Timestamp to ISO string:', err);
      return null;
    }
  }

  // Date object
  if (value instanceof Date) {
    try {
      return value.toISOString();
    } catch (err) {
      console.warn('Failed to convert Date to ISO string:', err);
      return null;
    }
  }

  // Number (Unix timestamp in milliseconds)
  if (typeof value === 'number') {
    try {
      return new Date(value).toISOString();
    } catch (err) {
      console.warn('Failed to convert number to ISO string:', err);
      return null;
    }
  }

  // String (already ISO or needs parsing)
  if (typeof value === 'string') {
    try {
      // Try to parse and re-format to ensure valid ISO
      const date = new Date(value);
      if (!isNaN(date.getTime())) {
        return date.toISOString();
      }
      return null;
    } catch (err) {
      console.warn('Failed to parse string as date:', err);
      return null;
    }
  }

  console.warn('Unknown time format, returning null:', typeof value);
  return null;
}
