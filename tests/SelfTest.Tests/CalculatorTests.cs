namespace SelfTest.Tests;

[TestClass]
public sealed class CalculatorTests
{
    [TestMethod]
    public void Add_ReturnsSum() => Assert.AreEqual(3, Calculator.Add(1, 2));
}
