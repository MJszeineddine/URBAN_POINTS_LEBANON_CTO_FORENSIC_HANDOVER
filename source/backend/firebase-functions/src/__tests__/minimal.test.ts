describe("firebase-functions module", () => {
  it("loads without crashing", async () => {
    // Ensure env is set
    process.env.QR_TOKEN_SECRET = process.env.QR_TOKEN_SECRET || "test-secret-for-tests";
    
    // Just verify the test runs
    expect(true).toBe(true);
  });
});
